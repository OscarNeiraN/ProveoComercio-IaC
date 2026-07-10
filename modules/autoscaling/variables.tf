variable "project_name" {
  type = string
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}

variable "launch_template_id" {
  type        = string
  description = "ID de la launch template a usar"
}

variable "vpc_zone_identifier" {
  type = list(string)
}

variable "target_group_arns" {
  type = list(string)
}

variable "autoscaling_config" {
  type = object({
    min_size                  = number
    max_size                  = number
    desired_capacity          = number
    health_check_type         = string
    health_check_grace_period = number
  })
}
