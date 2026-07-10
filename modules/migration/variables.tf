variable "project_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "migration_image" {
  type = string
}

variable "task_execution_role_name" {
  type = string
}

variable "task_execution_role_arn" {
  type    = string
  default = ""
}

variable "task_role_name" {
  type = string
}

variable "task_role_arn" {
  type    = string
  default = ""
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "db_name" {
  type = string
}

variable "db_user" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "cpu" {
  type    = number
  default = 512
}

variable "memory" {
  type    = number
  default = 1024
}
