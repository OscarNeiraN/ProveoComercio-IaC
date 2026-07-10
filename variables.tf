variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type = string
}

variable "enable_network" {
  type    = bool
  default = true
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnets_config" {
  type = map(object({
    az      = string
    net_num = number
    public  = bool
  }))
}

variable "frontend_image" {
  type    = string
  default = ""
}

variable "backend_image" {
  type    = string
  default = ""
}

variable "db_migrator_image" {
  type    = string
  default = ""
}

variable "jwt_secret" {
  type        = string
  default     = ""
  sensitive   = true
  description = "JWT signing secret for the backend. Leave empty to let Terraform generate one and store it in AWS Secrets Manager."
}

variable "frontend_port" {
  type    = number
  default = 80
}

variable "backend_port" {
  type    = number
  default = 3000
}

variable "frontend_desired_count" {
  type    = number
  default = 2
}

variable "backend_desired_count" {
  type    = number
  default = 2
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

variable "create_iam_roles" {
  type        = bool
  default     = true
  description = "Create ECS IAM roles. Set false in AWS Academy/Learner Lab and use LabRole."
}

variable "task_execution_role_name" {
  type        = string
  default     = ""
  description = "Existing IAM role name for ECS task execution when create_iam_roles is false."
}

variable "task_execution_role_arn" {
  type        = string
  default     = ""
  description = "Optional existing IAM role ARN for ECS task execution. Overrides task_execution_role_name when set."
}

variable "task_role_name" {
  type        = string
  default     = ""
  description = "Existing IAM role name for containers when create_iam_roles is false. Defaults to task_execution_role_name if empty."
}

variable "task_role_arn" {
  type        = string
  default     = ""
  description = "Optional existing IAM role ARN for containers. Overrides task_role_name when set."
}

variable "enable_ecs_autoscaling" {
  type        = bool
  default     = true
  description = "Create ECS Application Auto Scaling resources."
}

variable "ecs_cpu" {
  type    = number
  default = 512
}

variable "ecs_memory" {
  type    = number
  default = 1024
}

variable "db_config" {
  type = object({
    engine                  = string
    engine_version          = string
    instance_class          = string
    username                = string
    password                = string
    storage                 = number
    name                    = string
    publicly_accessible     = bool
    multi_az                = optional(bool, false)
    storage_encrypted       = optional(bool, true)
    backup_retention_period = optional(number, 7)
    deletion_protection     = optional(bool, false)
  })
  sensitive = true

  validation {
    condition     = var.db_config.publicly_accessible == false
    error_message = "RDS debe quedar privado: db_config.publicly_accessible debe ser false."
  }
}

variable "create_db" {
  type    = bool
  default = true
}

variable "external_db_host" {
  type    = string
  default = ""
}

variable "external_db_port" {
  type    = number
  default = 3306
}

variable "smtp_config" {
  type = object({
    host      = string
    port      = number
    user      = string
    password  = string
    secure    = bool
    mail_from = string
  })
  sensitive = true
  default = {
    host      = ""
    port      = 587
    user      = ""
    password  = ""
    secure    = false
    mail_from = ""
  }
}

variable "sqs_config" {
  type = object({
    max_receive_count          = number
    visibility_timeout_seconds = number
    message_retention_seconds  = number
    delay_seconds              = number
    receive_wait_time_seconds  = number
  })
  default = {
    max_receive_count          = 3
    visibility_timeout_seconds = 300
    message_retention_seconds  = 1209600
    delay_seconds              = 0
    receive_wait_time_seconds  = 20
  }
}

variable "alb_config" {
  type = object({
    name                 = string
    internal             = bool
    listener_port        = number
    protocol             = string
    frontend_port        = number
    backend_port         = number
    backend_path_pattern = string
    target_protocol      = string
  })
}
