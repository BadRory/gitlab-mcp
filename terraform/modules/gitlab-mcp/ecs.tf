resource "aws_ecs_cluster" "this" {
  name = local.name_prefix

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE"
    weight            = 1
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.name_prefix
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "gitlab-mcp"
      image     = local.image_uri
      essential = true

      portMappings = [
        {
          containerPort = 3002
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV",                    value = "production" },
        { name = "HOST",                        value = "0.0.0.0" },
        { name = "PORT",                        value = "3002" },
        { name = "STREAMABLE_HTTP",             value = "true" },
        { name = "GITLAB_MCP_OAUTH",            value = "true" },
        # Single registered redirect URI — the server proxies the OAuth callback
        # so each developer client doesn't need its own entry in GitLab.
        { name = "GITLAB_OAUTH_CALLBACK_PROXY", value = "true" },
        # Tokens are sealed in the Mcp-Session-Id header; no in-memory session
        # store means any ECS task can serve any request without sticky routing.
        { name = "OAUTH_STATELESS_MODE",        value = "true" },
        { name = "GITLAB_URL",                  value = var.gitlab_url },
        { name = "GITLAB_API_URL",              value = var.gitlab_api_url },
        { name = "MCP_SERVER_URL",              value = var.mcp_server_url },
        { name = "GITLAB_OAUTH_SCOPES",         value = var.gitlab_oauth_scopes },
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
        },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
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

resource "aws_ecs_service" "this" {
  name            = local.name_prefix
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_task.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "gitlab-mcp"
    container_port   = 3002
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # CI handles rolling deploys by registering a new task definition revision
  # and calling aws ecs update-service. Ignore drift here so Terraform doesn't
  # race with in-flight deployments.
  lifecycle {
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution_managed,
    aws_iam_role_policy.task_execution_secrets,
  ]
}
