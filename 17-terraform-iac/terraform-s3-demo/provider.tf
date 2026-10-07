terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # these tags get added to every resource this provider creates
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Session   = "18-terraform-iac"
    }
  }
}
