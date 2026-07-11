output "backup_vault_name" {
  value       = one(aws_backup_vault.main[*].name)
  description = "Nombre del vault de AWS Backup"
}

output "backup_vault_arn" {
  value       = one(aws_backup_vault.main[*].arn)
  description = "ARN del vault de AWS Backup"
}

output "backup_plan_id" {
  value       = one(aws_backup_plan.main[*].id)
  description = "ID del plan de AWS Backup"
}

output "backup_plan_arn" {
  value       = one(aws_backup_plan.main[*].arn)
  description = "ARN del plan de AWS Backup"
}

output "backup_selection_id" {
  value       = one(aws_backup_selection.rds[*].id)
  description = "ID de la seleccion de recursos respaldados por AWS Backup"
}

output "backup_role_arn" {
  value       = local.backup_role_arn
  description = "ARN del rol usado por AWS Backup para respaldar RDS"
}
