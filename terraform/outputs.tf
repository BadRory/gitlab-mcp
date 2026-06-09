output "alb_dns_name" {
  description = "DNS name of the internal ALB. Point your Cloudflare / Direct Connect origin record here."
  value       = aws_lb.gitlab_mcp.dns_name
}

output "alb_arn" {
  description = "ARN of the internal ALB"
  value       = aws_lb.gitlab_mcp.arn
}

output "ecr_repository_url" {
  description = "ECR repository URL. Use this as the image registry in CI."
  value       = aws_ecr_repository.gitlab_mcp.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.gitlab_mcp.name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.gitlab_mcp.name
}

output "cloudwatch_log_group" {
  description = "CloudWatch log group for ECS container logs"
  value       = aws_cloudwatch_log_group.gitlab_mcp.name
}

output "secrets_manager_oauth_credentials_arn" {
  description = "Secrets Manager ARN for GitLab OAuth credentials. Populate app_id and app_secret here after GitLab registration."
  value       = aws_secretsmanager_secret.gitlab_oauth_credentials.arn
}

output "secrets_manager_stateless_secret_arn" {
  description = "Secrets Manager ARN for the stateless session AES key (auto-generated)."
  value       = aws_secretsmanager_secret.oauth_stateless_secret.arn
}

output "gitlab_oauth_redirect_uri" {
  description = "Redirect URI to register in the GitLab OAuth application"
  value       = "${var.mcp_server_url}/callback"
}

output "mcp_endpoint" {
  description = "MCP Streamable HTTP endpoint URL for client configuration"
  value       = "${var.mcp_server_url}/mcp"
}
