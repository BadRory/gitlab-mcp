resource "aws_security_group" "ecs_task" {
  name        = "${local.name_prefix}-ecs-task"
  description = "${local.name_prefix} ECS tasks — inbound on :3002 from ALB only"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MCP server port from ALB"
    from_port       = 3002
    to_port         = 3002
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  # Outbound HTTPS to GitLab and AWS service endpoints
  egress {
    description = "HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
