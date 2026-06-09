variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-2"
}

variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "vpc_id" {
  description = "ID of the existing VPC where resources will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks and the internal ALB"
  type        = list(string)
}

variable "gitlab_url" {
  description = "Base URL of the self-hosted GitLab instance (e.g. https://gitlab.corp.com)"
  type        = string
}

variable "gitlab_api_url" {
  description = "GitLab REST API URL (e.g. https://gitlab.corp.com/api/v4)"
  type        = string
}

variable "mcp_server_url" {
  description = "Public-facing URL developers use to reach the MCP server (e.g. https://mcp.corp.com). Used as the OAuth redirect base and MCP server URL."
  type        = string
}

variable "certificate_arn" {
  description = "ACM certificate ARN for the ALB HTTPS listener. Must cover the domain in mcp_server_url."
  type        = string
}

# CIDRs that are permitted to send traffic to the internal ALB.
# Typical sources:
#   - Your AWS Direct Connect customer gateway CIDRs
#   - Cloudflare IP ranges (if routing through Cloudflare → Direct Connect)
#   - VPC CIDR (for internal health checks / inter-service calls)
variable "allowed_ingress_cidrs" {
  description = "CIDR blocks allowed to reach the ALB on port 443"
  type        = list(string)
}

variable "task_cpu" {
  description = "ECS task CPU units (256 = 0.25 vCPU)"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "ECS task memory in MiB"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "Docker image tag to deploy"
  type        = string
  default     = "latest"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

# Supply this to pre-seed the GitLab OAuth app credentials.
# If left empty, the secrets are created but you must populate them manually
# in AWS Secrets Manager after the GitLab OAuth application is registered.
variable "gitlab_oauth_app_id" {
  description = "GitLab OAuth application ID (Client ID). Set after registering the OAuth app in GitLab."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_oauth_app_secret" {
  description = "GitLab OAuth application secret. Set after registering the OAuth app in GitLab."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_oauth_scopes" {
  description = "Comma-separated GitLab OAuth scopes to request"
  type        = string
  default     = "api,read_user"
}
