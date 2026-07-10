variable "db_config" {}
variable "subnet_ids" {}
variable "security_group_id" {}

variable "create_db" {
  type    = bool
  default = true
}

variable "project_name" {
  type = string
}

