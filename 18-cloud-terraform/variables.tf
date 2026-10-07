variable "aws_region" {
  description = "AWS region to deploy everything into."
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Prefix used for Name tags and the bucket name."
  type        = string
  default     = "session19-ridaa"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type (free-tier eligible)."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Use t2.micro or t3.micro to stay in the free tier."
  }
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH (port 22). Set this to YOUR_IP/32, not 0.0.0.0/0."
  type        = string

  validation {
    condition     = can(cidrhost(var.ssh_allowed_cidr, 0))
    error_message = "ssh_allowed_cidr must be a valid CIDR, e.g. 203.0.113.10/32."
  }
}

variable "key_name" {
  description = "Optional existing EC2 key pair name for SSH. Leave null to skip."
  type        = string
  default     = null
}
