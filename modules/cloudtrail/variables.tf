variable "project_name" {
  type = string
}

variable "enable_cloudtrail" {
  type        = bool
  default     = true
  description = "Crea un trail de CloudTrail (auditoria de quien hace que en la cuenta AWS)."
}

variable "log_retention_days" {
  type        = number
  default     = 180
  description = "Dias que se conservan los logs de CloudTrail en S3 antes de borrarse."
}
