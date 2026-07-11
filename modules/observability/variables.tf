variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "sns_topic_arn" {
  type        = string
  description = "ARN del topico SNS (modulo alerts) al que se envian todas las alarmas"
}

variable "ecs_cluster_name" {
  type = string
}

variable "frontend_service_name" {
  type = string
}

variable "backend_service_name" {
  type = string
}

variable "worker_service_name" {
  type = string
}

variable "db_instance_id" {
  type = string
}

variable "backend_alb_arn_suffix" {
  type = string
}

variable "backend_target_group_arn_suffix" {
  type = string
}

variable "sqs_dlq_name" {
  type = string
}

variable "rds_free_storage_threshold_bytes" {
  type        = number
  default     = 2147483648
  description = "Umbral de alarma de espacio libre en RDS. Default 2 GiB."
}
