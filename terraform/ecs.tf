resource "aws_ecs_cluster" "gitlab_mcp" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "gitlab_mcp" {
  cluster_name       = aws_ecs_cluster.gitlab_mcp.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "gitlab_mcp" {
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "gitlab-mcp"
      image     = local.ecr_image_uri
      essential = true

      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV",                        value = "production" },
        { name = "HOST",                            value = "0.0.0.0" },
        { name = "PORT",                            value = "3002" },
        { name = "STREAMABLE_HTTP",                 value = "true" },
        { name = "GITLAB_MCP_OAUTH",                value = "true" },
        # Single registered redirect URI in GitLab — the server proxies the
        # OAuth callback so each developer client doesn't need its own entry.
        { name = "GITLAB_OAUTH_CALLBACK_PROXY",     value = "true" },
        # Stateless session tokens — any ECS task can decode any session,
        # eliminating the need for sticky load balancer sessions.
        { name = "OAUTH_STATELESS_MODE",            value = "true" },
        { name = "GITLAB_URL",                      value = var.gitlab_url },
        { name = "GITLAB_API_URL",                  value = var.gitlab_api_url },
        { name = "MCP_SERVER_URL",                  value = var.mcp_server_url },
        { name = "GITLAB_OAUTH_SCOPES",             value = var.gitlab_oauth_scopes },
      ]

      secrets = [
        {
          name      = "OAUTH_STATELESS_SECRET"
          valueFrom = aws_secretsmanager_secret.oauth_stateless_secret.arn
        },
        {
          name      = "GITLAB_OAUTH_APP_ID"
          valueFrom = "${aws_secretsmanager_secret.gitlab_oauth_credentials.arn}:app_id::"
        },
        {
          name      = "GITLAB_OAUTH_APP_SECRET"
          valueFrom = "${aws_secretsmanager_secret.gitlab_oauth_credentials.arn}:app_secret::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.gitlab_mcp.name
          "awslogs-region"        = local.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "wget -qO- http://localhost:3002/health || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 30
      }
    }
  ])
}

resource "aws_ecs_service" "gitlab_mcp" {
  name            = local.name_prefix
  cluster         = aws_ecs_cluster.gitlab_mcp.id
  task_definition = aws_ecs_task_definition.gitlab_mcp.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.gitlab_mcp.arn
    container_name   = "gitlab-mcp"
    container_port   = 3002
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_controller {
    type = "ECS"
  }

  # Ignore image tag changes — CI handles rolling deploys via `aws ecs update-service`
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_lb_listener.https,
    aws_iam_role_policy_attachment.ecs_task_execution_managed,
    aws_iam_role_policy.ecs_task_execution_secrets,
  ]
}
