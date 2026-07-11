data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "backup_assume_role" {
  count = var.enable_backup && var.create_iam_role ? 1 : 0

  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

locals {
  existing_backup_role_arn = var.backup_role_arn != "" ? var.backup_role_arn : "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.backup_role_name}"
  backup_role_arn          = var.enable_backup ? (var.create_iam_role ? aws_iam_role.backup[0].arn : local.existing_backup_role_arn) : null
}

resource "aws_iam_role" "backup" {
  count              = var.enable_backup && var.create_iam_role ? 1 : 0
  name               = "${var.project_name}-aws-backup-role"
  assume_role_policy = data.aws_iam_policy_document.backup_assume_role[0].json

  tags = {
    Name = "${var.project_name}-aws-backup-role"
  }
}

resource "aws_iam_role_policy_attachment" "backup" {
  count      = var.enable_backup && var.create_iam_role ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_vault" "main" {
  count       = var.enable_backup ? 1 : 0
  name        = lower("${var.project_name}-rds-backup-vault")
  kms_key_arn = var.vault_kms_key_arn != "" ? var.vault_kms_key_arn : null

  tags = {
    Name        = lower("${var.project_name}-rds-backup-vault")
    Project     = var.project_name
    Service     = "aws-backup"
    Encryption  = var.vault_kms_key_arn != "" ? "customer-managed-kms" : "aws-managed"
    Environment = "production"
  }
}

resource "aws_backup_plan" "main" {
  count = var.enable_backup ? 1 : 0
  name  = lower("${var.project_name}-rds-daily-backup-plan")

  rule {
    rule_name         = lower("${var.project_name}-rds-daily")
    target_vault_name = aws_backup_vault.main[0].name
    schedule          = var.schedule
    start_window      = var.start_window_minutes
    completion_window = var.completion_window_minutes

    lifecycle {
      delete_after = var.retention_days
    }

    recovery_point_tags = {
      Project    = var.project_name
      ManagedBy  = "terraform"
      BackupType = "daily-rds"
    }
  }

  tags = {
    Name    = lower("${var.project_name}-rds-daily-backup-plan")
    Project = var.project_name
  }
}

resource "aws_backup_selection" "rds" {
  count        = var.enable_backup ? 1 : 0
  name         = lower("${var.project_name}-rds-backup-selection")
  iam_role_arn = local.backup_role_arn
  plan_id      = aws_backup_plan.main[0].id
  resources    = var.resource_arns

  lifecycle {
    precondition {
      condition     = var.create_iam_role || var.backup_role_arn != "" || var.backup_role_name != ""
      error_message = "Si create_iam_role es false, debes definir backup_role_name o backup_role_arn para AWS Backup."
    }
  }
}
