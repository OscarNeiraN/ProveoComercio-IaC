variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "backend_upstream" {
  type = string
}

variable "backend_resolver" {
  type = string
}

variable "create_iam_roles" {
  type    = bool
  default = true
}

variable "task_execution_role_name" {
  type    = string
  default = ""
}

variable "task_execution_role_arn" {
  type    = string
  default = ""
}

variable "task_role_name" {
  type    = string
  default = ""
}

variable "task_role_arn" {
  type    = string
  default = ""
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}

variable "frontend_image" {
  type = string
}

variable "backend_image" {
  type = string
}

variable "frontend_port" {
  type = number
}

variable "backend_port" {
  type = number
}

variable "frontend_desired_count" {
  type = number
}

variable "frontend_min_capacity" {
  type    = number
  default = 2
}

variable "frontend_max_capacity" {
  type    = number
  default = 8
}

variable "backend_desired_count" {
  type = number
}

variable "backend_min_capacity" {
  type    = number
  default = 2
}

variable "backend_max_capacity" {
  type    = number
  default = 8
}

variable "cpu" {
  type = number
}

variable "cpu_target_utilization" {
  type    = number
  default = 80
}

variable "memory" {
  type = number
}

variable "subnet_ids" {
  type = list(string)
}

variable "frontend_security_group_ids" {
  type = list(string)
}

variable "backend_security_group_ids" {
  type = list(string)
}

variable "worker_security_group_ids" {
  type = list(string)
}

variable "frontend_target_group_arn" {
  type = string
}

variable "backend_target_group_arn" {
  type = string
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type    = number
  default = 3306
}

variable "db_name" {
  type = string
}

variable "db_user_secret_arn" {
  type = string
}

variable "db_password_secret_arn" {
  type = string
}

variable "jwt_secret_arn" {
  type = string
}

variable "smtp_host" {
  type    = string
  default = ""
}

variable "smtp_port" {
  type    = number
  default = 587
}

variable "smtp_user_secret_arn" {
  type = string
}

variable "smtp_password_secret_arn" {
  type = string
}

variable "smtp_secure" {
  type    = bool
  default = false
}

variable "mail_from" {
  type    = string
  default = ""
}

variable "sqs_queue_url" {
  type = string
}

variable "sqs_queue_arn" {
  type = string
}

variable "sqs_queue_name" {
  type = string
}

variable "worker_desired_count" {
  type    = number
  default = 1
}

variable "worker_min_capacity" {
  type    = number
  default = 1
}

variable "worker_max_capacity" {
  type    = number
  default = 4
}

variable "worker_queue_messages_per_task" {
  type    = number
  default = 5
}
