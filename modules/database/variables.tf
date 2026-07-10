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
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "create_db" {
  type    = bool
  default = true
}

variable "project_name" {
  type = string
}

