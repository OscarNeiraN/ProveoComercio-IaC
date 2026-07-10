resource "random_password" "jwt_secret" {
  count   = var.jwt_secret == "" ? 1 : 0
  length  = 48
  special = true
}

locals {
  app_secret_values = {
    db_user       = var.db_config.username
    db_password   = var.db_config.password
    jwt_secret    = var.jwt_secret != "" ? var.jwt_secret : random_password.jwt_secret[0].result
    smtp_user     = var.smtp_config.user
    smtp_password = var.smtp_config.password
  }
}

resource "aws_secretsmanager_secret" "app" {
  for_each                = local.app_secret_values
  name                    = "${var.project_name}/app/${replace(each.key, "_", "-")}"
  recovery_window_in_days = 7

  tags = {
    Name    = "${var.project_name}-${replace(each.key, "_", "-")}"
    Project = var.project_name
  }
}

resource "aws_secretsmanager_secret_version" "app" {
  for_each      = local.app_secret_values
  secret_id     = aws_secretsmanager_secret.app[each.key].id
  secret_string = each.value
}
