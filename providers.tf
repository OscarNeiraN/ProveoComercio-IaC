terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.6" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
  }

  # Bucket creado una sola vez, a mano, con Terraform/bootstrap/. use_lockfile
  # usa locking nativo de S3 (Terraform >= 1.10), no necesita tabla DynamoDB aparte.
  backend "s3" {
    bucket       = "proveocomercio-tfstate-a6fa98c1"
    key          = "proveocomercio/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" { region = var.aws_region }
