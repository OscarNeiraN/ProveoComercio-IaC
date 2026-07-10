variable "vpc_cidr" {
  type = string
}

variable "project_name" {
  type = string
}

variable "subnets_config" {
  type = map(object({
    az      = string
    net_num = number
    public  = bool
  }))
}

variable "enable_network" {
  type    = bool
  default = true
}

variable "nat_gateway_per_az" {
  type        = bool
  default     = true
  description = "true = un NAT Gateway por AZ (alta disponibilidad, mayor costo). false = un unico NAT Gateway compartido (punto unico de falla, mas barato)."
}