##############################################################################
# ALB Security Group
# Accepts HTTPS from Direct Connect / Cloudflare CIDRs.
# Forwards to ECS tasks on port 3002.
##############################################################################

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb"
  description = "gitlab-mcp internal ALB — allow HTTPS from approved CIDRs"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_ingress_cidrs
    content {
      description = "HTTPS from approved network"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    description     = "Forward to ECS tasks"
    from_port       = 3002
    to_port         = 3002
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_task.id]
  }
}

##############################################################################
# ECS Task Security Group
# Accepts traffic from the ALB only.
# Allows outbound HTTPS to GitLab (in VPC) and AWS APIs.
##############################################################################

resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task"
  description = "gitlab-mcp ECS tasks — inbound from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MCP server port from ALB"
    from_port       = 3002
    to_port         = 3002
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Outbound HTTPS: GitLab API + AWS service endpoints (ECR, Secrets Manager, CloudWatch)
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound HTTP — kept for flexibility (GitLab on port 80, package mirrors).
  # Remove if your GitLab instance enforces HTTPS-only.
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
