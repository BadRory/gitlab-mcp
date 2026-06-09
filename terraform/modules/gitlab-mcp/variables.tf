##############################################################################
# Networking — supplied by your VPC / networking module outputs
##############################################################################

variable "vpc_id" {
  description = "ID of the VPC to deploy into"
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs for ECS tasks. Subnets must have routes to GitLab and to AWS service endpoints (ECR, Secrets Manager, CloudWatch)."
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "Security group ID of the ALB that will forward to this service. Used to create the ECS task SG ingress rule on port 3002."
  type        = string
}

##############################################################################
# Application config
##############################################################################

variable "gitlab_url" {
  description = "Base URL of the self-hosted GitLab instance (e.g. https://gitlab.corp.com)"
  type        = string
}

variable "gitlab_api_url" {
  description = "GitLab REST API base URL (e.g. https://gitlab.corp.com/api/v4)"
  type        = string
}

variable "mcp_server_url" {
  description = "Externally reachable URL of this MCP server (e.g. https://mcp.corp.com). Used as the OAuth issuer and in the redirect URI."
  type        = string
}

variable "gitlab_oauth_scopes" {
  description = "Comma-separated GitLab OAuth scopes to request during the auth flow"
  type        = string
  default     = "api,read_user"
}

##############################################################################
# Naming / environment
##############################################################################

variable "name" {
  description = "Resource name prefix (e.g. gitlab-mcp)"
  type        = string
  default     = "gitlab-mcp"
}

variable "environment" {
  description = "Deployment environment label applied to all resources (e.g. prod, staging)"
  type        = string
}

##############################################################################
# Capacity
##############################################################################

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
  description = "Number of ECS tasks to keep running"
  type        = number
  default     = 2
}

variable "image_tag" {
  description = "Docker image tag to run"
  type        = string
  default     = "latest"
}

variable "log_retention_days" {
  description = "CloudWatch log group retention period in days"
  type        = number
  default     = 30
}

##############################################################################
# Pre-seeded secrets (optional — can be left empty and populated manually)
##############################################################################

variable "gitlab_oauth_app_id" {
  description = "GitLab OAuth application ID. Register the app in GitLab Admin → Applications first; the redirect URI must be <mcp_server_url>/callback."
  type        = string
  default     = ""
  sensitive   = true
}

variable "gitlab_oauth_app_secret" {
  description = "GitLab OAuth application secret."
  type        = string
  default     = ""
  sensitive   = true
}
