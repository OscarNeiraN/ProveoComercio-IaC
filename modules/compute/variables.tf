variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_map_ids" { type = map(string) }
variable "instances_config" { type = map(any) }
variable "enable_compute" { type = bool }
variable "vpc_security_group_ids" {
  type = list(string)
}

variable "key_name" {
  type = string
}

variable "ami_id" {
  description = "ID de la AMI proporcionado por la raiz"
  type        = string
}
