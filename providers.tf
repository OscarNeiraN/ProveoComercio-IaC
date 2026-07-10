terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" { region = var.aws_region }