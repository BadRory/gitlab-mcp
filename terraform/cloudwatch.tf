resource "aws_cloudwatch_log_group" "gitlab_mcp" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = var.log_retention_days
}
