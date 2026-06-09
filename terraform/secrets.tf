resource "random_bytes" "oauth_stateless_secret" {
  length = 32
}

# AES-256 key used to seal stateless MCP session tokens.
# All ECS tasks share this key so any pod can decrypt any session —
# this is what makes the deployment horizontally scalable without sticky sessions.
resource "aws_secretsmanager_secret" "oauth_stateless_secret" {
  name                    = "${local.name_prefix}/oauth-stateless-secret"
  description             = "AES-256 key for gitlab-mcp stateless session encryption"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "oauth_stateless_secret" {
  secret_id     = aws_secretsmanager_secret.oauth_stateless_secret.id
  secret_string = random_bytes.oauth_stateless_secret.base64
}

# GitLab OAuth application credentials.
# Populate app_id and app_secret after registering the OAuth application in GitLab:
#   Admin > Applications > New application
#   Scopes: api, read_user
#   Redirect URI: <mcp_server_url>/callback
resource "aws_secretsmanager_secret" "gitlab_oauth_credentials" {
  name                    = "${local.name_prefix}/gitlab-oauth-credentials"
  description             = "GitLab OAuth app credentials for gitlab-mcp"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "gitlab_oauth_credentials" {
  secret_id = aws_secretsmanager_secret.gitlab_oauth_credentials.id
  secret_string = jsonencode({
    app_id     = var.gitlab_oauth_app_id
    app_secret = var.gitlab_oauth_app_secret
  })
}
