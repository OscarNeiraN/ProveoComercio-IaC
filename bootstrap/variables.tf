variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  type        = string
  default     = "proveocomercio-tfstate-a6fa98c1"
  description = "Nombre del bucket S3 para el remote state. Debe ser unico a nivel global en AWS."
}
