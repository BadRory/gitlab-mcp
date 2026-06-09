resource "random_bytes" "oauth_stateless_secret" {
  length = 32
}

# AES-256 key shared across all ECS tasks. Any pod can decrypt any session
# without sticky routing because tokens are sealed client-side in Mcp-Session-Id.
resource "aws_secretsmanager_secret" "oauth_stateless_secret" {
  name                    = "${local.name_prefix}/oauth-stateless-secret"
  description             = "AES-256 stateless session key for ${local.name_prefix}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "oauth_stateless_secret" {
  secret_id     = aws_secretsmanager_secret.oauth_stateless_secret.id
  secret_string = random_bytes.oauth_stateless_secret.base64
}

# GitLab OAuth application credentials.
# If var.gitlab_oauth_app_id / app_secret are empty, populate manually after
# registering the OAuth app in GitLab: Admin → Applications → New application
#   Scopes: api, read_user
#   Redirect URI: <mcp_server_url>/callback (see module output: gitlab_oauth_redirect_uri)
resource "aws_secretsmanager_secret" "gitlab_oauth_credentials" {
  name                    = "${local.name_prefix}/gitlab-oauth-credentials"
  description             = "GitLab OAuth app credentials for ${local.name_prefix}"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "gitlab_oauth_credentials" {
  secret_id = aws_secretsmanager_secret.gitlab_oauth_credentials.id
  secret_string = jsonencode({
    app_id     = var.gitlab_oauth_app_id
    app_secret = var.gitlab_oauth_app_secret
  })
}
