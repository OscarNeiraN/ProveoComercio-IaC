terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }

  # Este proyecto se aplica una sola vez, a mano, para crear el bucket que despues
  # usa el backend "s3" del proyecto principal (Terraform/providers.tf). No puede
  # usar ese mismo bucket como backend porque todavia no existe: se queda con state
  # local a proposito.
  backend "local" {
    path = "bootstrap.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
}
