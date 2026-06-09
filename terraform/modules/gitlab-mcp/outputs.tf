##############################################################################
# Wire these into your ALB / SG modules
##############################################################################

output "target_group_arn" {
  description = "ALB target group ARN. Pass to your ALB module as the listener rule target."
  value       = aws_lb_target_group.this.arn
}

output "ecs_task_security_group_id" {
  description = "Security group ID of the ECS tasks. Add as an egress target in your ALB security group module if needed."
  value       = aws_security_group.ecs_task.id
}

##############################################################################
# CI / deployment
##############################################################################

output "ecr_repository_url" {
  description = "ECR repository URL. Use as the image registry in CI pipelines."
  value       = aws_ecr_repository.this.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.this.name
}

output "ecs_task_definition_family" {
  description = "ECS task definition family name"
  value       = aws_ecs_task_definition.this.family
}

##############################################################################
# Secrets — for post-deploy population and auditing
##############################################################################

output "oauth_credentials_secret_arn" {
  description = "Secrets Manager ARN for the GitLab OAuth app credentials (app_id + app_secret). Populate after GitLab app registration if not pre-seeded."
  value       = aws_secretsmanager_secret.gitlab_oauth_credentials.arn
}

output "stateless_secret_arn" {
  description = "Secrets Manager ARN for the auto-generated AES-256 stateless session key."
  value       = aws_secretsmanager_secret.oauth_stateless_secret.arn
}

##############################################################################
# Useful reference values
##############################################################################

output "cloudwatch_log_group_name" {
  description = "CloudWatch log group for ECS container logs"
  value       = aws_cloudwatch_log_group.this.name
}

output "gitlab_oauth_redirect_uri" {
  description = "Redirect URI to register in the GitLab OAuth application (Admin → Applications)."
  value       = "${var.mcp_server_url}/callback"
}

output "mcp_endpoint" {
  description = "MCP Streamable HTTP endpoint URL for developer client configuration."
  value       = "${var.mcp_server_url}/mcp"
}
