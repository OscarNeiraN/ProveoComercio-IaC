variable "vpc_cidr" {}
variable "project_name" {}
variable "subnets_config" {}

variable "enable_network" {
  type    = bool
  default = true
}