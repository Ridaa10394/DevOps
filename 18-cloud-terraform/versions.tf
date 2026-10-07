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

  # Remote state (optional) - uncomment after creating the bucket + lock table
  # backend "s3" {
  #   bucket       = "ridaa-tfstate-bucket"
  #   key          = "session19/terraform.tfstate"
  #   region       = "ap-south-1"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      Session   = "19"
      Owner     = "Ridaa Mirza"
      ManagedBy = "Terraform"
    }
  }
}
