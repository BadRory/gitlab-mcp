# gitlab-mcp Terraform Module

Deploys the GitLab MCP server as an ECS Fargate service.

The module creates its own ECS cluster, task definition, task IAM roles, ECR repository, ALB target group, ECS task security group, Secrets Manager secrets, and CloudWatch log group.

It does **not** create the ALB, listener rules, or ACM certificate — those come from your existing infrastructure modules.

## Usage

```hcl
module "gitlab_mcp" {
  source = "github.com/BadRory/gitlab-mcp//terraform/modules/gitlab-mcp"

  # Networking — from your VPC module outputs
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnet_ids   # or whichever tier hosts ECS
  alb_security_group_id = module.alb.security_group_id

  # Application config
  gitlab_url     = "https://gitlab.corp.com"
  gitlab_api_url = "https://gitlab.corp.com/api/v4"
  mcp_server_url = "https://mcp.corp.com"   # Cloudflare hostname

  environment = "prod"
}

# Wire the target group into your ALB module
module "alb_listener_rule" {
  source = "..."

  target_group_arn = module.gitlab_mcp.target_group_arn
  host_header      = "mcp.corp.com"
  priority         = 100
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| `vpc_id` | VPC to deploy into | `string` | yes |
| `subnet_ids` | Private subnet IDs for ECS tasks | `list(string)` | yes |
| `alb_security_group_id` | ALB SG ID — grants it ingress to ECS tasks on :3002 | `string` | yes |
| `gitlab_url` | GitLab base URL | `string` | yes |
| `gitlab_api_url` | GitLab API URL | `string` | yes |
| `mcp_server_url` | External MCP server URL (OAuth issuer / redirect base) | `string` | yes |
| `environment` | Environment label (e.g. `prod`) | `string` | yes |
| `name` | Resource name prefix | `string` | `"gitlab-mcp"` |
| `gitlab_oauth_scopes` | GitLab OAuth scopes | `string` | `"api,read_user"` |
| `task_cpu` | ECS task CPU units | `number` | `512` |
| `task_memory` | ECS task memory (MiB) | `number` | `1024` |
| `desired_count` | Number of ECS tasks | `number` | `2` |
| `image_tag` | Docker image tag | `string` | `"latest"` |
| `log_retention_days` | CloudWatch retention (days) | `number` | `30` |
| `gitlab_oauth_app_id` | GitLab OAuth app ID (can populate post-deploy) | `string` | `""` |
| `gitlab_oauth_app_secret` | GitLab OAuth app secret | `string` | `""` |

## Outputs

| Name | Description |
|------|-------------|
| `target_group_arn` | Pass to your ALB module for listener rule wiring |
| `ecs_task_security_group_id` | ECS task SG — add as egress target in ALB SG if needed |
| `ecr_repository_url` | Image registry URL for CI pipelines |
| `ecs_cluster_name` | For `aws ecs update-service` in CI |
| `ecs_service_name` | For `aws ecs update-service` in CI |
| `ecs_task_definition_family` | Task definition family name |
| `cloudwatch_log_group_name` | `/ecs/gitlab-mcp-<env>` |
| `oauth_credentials_secret_arn` | Secrets Manager ARN for GitLab OAuth credentials |
| `stateless_secret_arn` | Secrets Manager ARN for the AES session key |
| `gitlab_oauth_redirect_uri` | Redirect URI to register in the GitLab OAuth app |
| `mcp_endpoint` | MCP endpoint URL to give to developers |

## Post-deploy steps

1. **Register the GitLab OAuth application** (if not done yet):
   - GitLab Admin → Applications → New application
   - Redirect URI: `<output: gitlab_oauth_redirect_uri>`
   - Scopes: `api`, `read_user`
   - Note the Application ID and Secret

2. **Populate credentials** (if `gitlab_oauth_app_id` was left empty):
   ```bash
   aws secretsmanager put-secret-value \
     --secret-id "<output: oauth_credentials_secret_arn>" \
     --secret-string '{"app_id":"<ID>","app_secret":"<SECRET>"}'
   ```
   Then force a new ECS deployment to pick up the updated secret:
   ```bash
   aws ecs update-service \
     --cluster <output: ecs_cluster_name> \
     --service <output: ecs_service_name> \
     --force-new-deployment
   ```

3. **Point Cloudflare DNS** at your ALB.

4. **Give developers** the MCP endpoint: `<output: mcp_endpoint>`
