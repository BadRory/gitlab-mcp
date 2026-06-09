# AWS Enterprise Deployment Guide

This guide covers deploying the GitLab MCP server to AWS for an enterprise setup where developers connect from Claude Desktop or their IDE to a centrally-hosted, OAuth-authenticated MCP server.

## Architecture

```
Developer (Claude Desktop / IDE)
        │  HTTPS — MCP Streamable HTTP
        ▼
  ┌─────────────────────────────────────┐
  │  Cloudflare  (DNS + DDoS / Access)  │
  └────────────────┬────────────────────┘
                   │  via AWS Direct Connect
                   ▼
  ┌─────────────────────────────────────┐
  │  Internal ALB  (TLS termination)    │
  │  Private VPC subnets                │
  └────────────────┬────────────────────┘
                   │  HTTP :3002
         ┌─────────┴──────────┐
         ▼                    ▼
  ┌──────────────┐   ┌──────────────┐   ECS Fargate tasks
  │  gitlab-mcp  │   │  gitlab-mcp  │   (stateless — no sticky sessions)
  └──────┬───────┘   └──────┬───────┘
         └─────────┬─────────┘
                   │  HTTPS
                   ▼
  ┌─────────────────────────────────────┐
  │  Self-hosted GitLab  (private VPC)  │
  └─────────────────────────────────────┘
```

**Key design properties:**
- The ALB is *internal* — only reachable via Direct Connect (and optionally Cloudflare)
- ECS tasks run in private subnets with no public IPs
- Session tokens are AES-256-GCM encrypted and stored client-side (`Mcp-Session-Id` header) — no sticky sessions needed
- Each developer authenticates as themselves via GitLab OAuth; no shared service account

## OAuth Flow

1. Developer opens Claude Desktop. The MCP server is configured with `https://mcp.corp.com/mcp`.
2. Claude initiates auth — hits `GET /authorize` on the MCP server.
3. Server redirects the developer's browser to GitLab's OAuth login page.
4. Developer logs in with their GitLab credentials.
5. GitLab redirects to `https://mcp.corp.com/callback` (the one registered redirect URI).
6. Server exchanges the code for a GitLab access token, seals it in the `Mcp-Session-Id` header (AES-256-GCM, server-side secret).
7. All subsequent MCP tool calls use that developer's GitLab token transparently.

## Prerequisites

- AWS account with an existing VPC and private subnets
- Private subnets must have routes to:
  - Your self-hosted GitLab instance
  - AWS service endpoints (ECR, Secrets Manager, CloudWatch) — via VPC endpoints or NAT gateway
- Direct Connect virtual interface (VIF) or VPN connected to your network
- Cloudflare account with the MCP domain managed there
- ACM certificate for the MCP domain (in the same region as the ALB)
- A GitLab OAuth application registered (see below)

## Step 1 — Register the GitLab OAuth Application

In your self-hosted GitLab as an admin:

1. Go to **Admin Area → Applications → New application**
2. Fill in:
   - **Name:** `GitLab MCP Server`
   - **Redirect URI:** `https://mcp.corp.com/callback`
   - **Scopes:** `api`, `read_user`
   - **Confidential:** Yes
3. Save and note the **Application ID** and **Secret**

## Step 2 — Deploy Infrastructure with Terraform

```bash
cd terraform

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# Initialise (configure backend in main.tf first)
terraform init

# Review the plan
terraform plan

# Apply
terraform apply
```

After apply, note the outputs:

```
alb_dns_name                        = "internal-gitlab-mcp-prod-xxxx.ap-southeast-2.elb.amazonaws.com"
ecr_repository_url                  = "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/gitlab-mcp-prod"
gitlab_oauth_redirect_uri           = "https://mcp.corp.com/callback"   ← confirm this matches GitLab
mcp_endpoint                        = "https://mcp.corp.com/mcp"        ← give this to developers
secrets_manager_oauth_credentials_arn = "arn:aws:secretsmanager:..."
```

## Step 3 — Populate OAuth Credentials

If you didn't set `gitlab_oauth_app_id` / `gitlab_oauth_app_secret` in `terraform.tfvars`, populate them now:

```bash
aws secretsmanager put-secret-value \
  --secret-id "gitlab-mcp-prod/gitlab-oauth-credentials" \
  --secret-string '{"app_id":"<YOUR_APP_ID>","app_secret":"<YOUR_APP_SECRET>"}'
```

## Step 4 — Configure Cloudflare

1. **DNS** — Create a CNAME record pointing `mcp.corp.com` to the ALB DNS name from the Terraform output.
   - Set **Proxy status** to **Proxied** (orange cloud) if routing through Cloudflare CDN.
   - Or **DNS only** (grey cloud) if Cloudflare is purely for DNS and Direct Connect handles routing.

2. **Origin** — Configure the Cloudflare origin to route via your Direct Connect IP / Transit Gateway.

3. **(Optional) Cloudflare Access** — Add a Zero Trust Access policy for `mcp.corp.com` to restrict access to users in your organisation's identity provider (e.g., Okta, Azure AD). This is a second layer of auth on top of GitLab OAuth.

## Step 5 — Build and Push the Docker Image

The GitHub Actions workflow (`.github/workflows/deploy.yml`) automates this on push to `main`.

**First-time manual push:**

```bash
aws ecr get-login-password --region ap-southeast-2 \
  | docker login --username AWS --password-stdin \
    123456789012.dkr.ecr.ap-southeast-2.amazonaws.com

docker build -t gitlab-mcp .
docker tag gitlab-mcp \
  123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/gitlab-mcp-prod:latest
docker push \
  123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/gitlab-mcp-prod:latest
```

**Force a new ECS deployment:**
```bash
aws ecs update-service \
  --cluster gitlab-mcp-prod \
  --service gitlab-mcp-prod \
  --force-new-deployment
```

## Step 6 — Configure GitHub Actions

Add these secrets to your GitHub repository:

| Secret | Value |
|--------|-------|
| `AWS_DEPLOY_ROLE_ARN` | ARN of an IAM role with ECR push + ECS deploy permissions |

The workflow uses OIDC (no long-lived AWS keys). Create the role with a trust policy for your GitHub org:

```json
{
  "Effect": "Allow",
  "Principal": { "Federated": "arn:aws:iam::<ACCOUNT>:oidc-provider/token.actions.githubusercontent.com" },
  "Action": "sts:AssumeRoleWithWebIdentity",
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": "repo:<YOUR_ORG>/gitlab-mcp:*"
    }
  }
}
```

## Developer Client Configuration

Distribute this MCP server configuration to developers:

**Claude Desktop** (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "gitlab": {
      "url": "https://mcp.corp.com/mcp"
    }
  }
}
```

On first use, Claude Desktop opens a browser window to complete the GitLab OAuth login. The session is then persisted in the `Mcp-Session-Id` header and refreshed automatically.

## Key Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `STREAMABLE_HTTP` | `true` | Enables HTTP streaming transport (required for remote clients) |
| `GITLAB_MCP_OAUTH` | `true` | Enables the OAuth2 proxy flow |
| `GITLAB_OAUTH_CALLBACK_PROXY` | `true` | Single registered redirect URI; server proxies the callback |
| `OAUTH_STATELESS_MODE` | `true` | Sessions sealed in encrypted headers — no in-memory state, no sticky sessions |
| `OAUTH_STATELESS_SECRET` | from Secrets Manager | AES-256 key shared across all ECS tasks |
| `HOST` | `0.0.0.0` | Bind to all interfaces (required inside ECS container) |
| `GITLAB_URL` | `https://gitlab.corp.com` | Base URL for GitLab OAuth redirect |
| `GITLAB_API_URL` | `https://gitlab.corp.com/api/v4` | GitLab REST API endpoint |
| `MCP_SERVER_URL` | `https://mcp.corp.com` | Canonical external URL — used in OAuth metadata |

## Monitoring

- **Container logs:** CloudWatch log group `/ecs/gitlab-mcp-prod`
- **ALB metrics:** Available in CloudWatch under `AWS/ApplicationELB`
- **Health endpoint:** `GET https://mcp.corp.com/health` returns `{"status":"healthy","activeSessions":N,...}`
- **Metrics endpoint:** `GET /metrics` returns session and uptime data

## Scaling

The deployment is horizontally scalable by design:
- Increase `desired_count` in `terraform.tfvars` and re-apply
- No sticky sessions required (stateless token encryption)
- ALB distributes connections across all tasks

For autoscaling, add an `aws_appautoscaling_target` + `aws_appautoscaling_policy` targeting CPU or ALB request count.
