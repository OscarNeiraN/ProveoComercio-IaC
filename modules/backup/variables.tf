variable "project_name" {
  type = string
}

variable "enable_backup" {
  type    = bool
  default = true
}

variable "resource_arns" {
  type        = list(string)
  description = "ARNs de los recursos que AWS Backup debe respaldar"
}

variable "schedule" {
  type        = string
  description = "Expresion cron de AWS Backup en UTC"
}

variable "start_window_minutes" {
  type        = number
  description = "Minutos que AWS Backup puede esperar para iniciar el job"
}

variable "completion_window_minutes" {
  type        = number
  description = "Minutos maximos para completar el job de backup"
}

variable "retention_days" {
  type        = number
  description = "Dias de retencion de los recovery points"
}

variable "vault_kms_key_arn" {
  type        = string
  default     = ""
  description = "ARN opcional de una CMK de KMS para cifrar el backup vault. Si queda vacio, AWS Backup usa cifrado administrado por AWS."
}

variable "create_iam_role" {
  type        = bool
  default     = true
  description = "Crea un rol IAM dedicado para AWS Backup. En Learner Lab puede quedar false para reutilizar un rol existente."
}

variable "backup_role_name" {
  type        = string
  default     = ""
  description = "Nombre del rol existente que AWS Backup debe usar cuando create_iam_role es false."
}

variable "backup_role_arn" {
  type        = string
  default     = ""
  description = "ARN del rol existente que AWS Backup debe usar cuando create_iam_role es false. Tiene prioridad sobre backup_role_name."
}
