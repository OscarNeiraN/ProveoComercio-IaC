variable "project_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "backend_subnet_ids" {
  type = list(string)
}

variable "backend_security_group_ids" {
  type = list(string)
}

variable "enable_alb" {
  type    = bool
  default = true
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
