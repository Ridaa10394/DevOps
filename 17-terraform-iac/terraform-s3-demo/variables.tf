variable "aws_region" {
  type        = string
  description = "AWS region where the S3 bucket will be created."
  default     = "ap-south-1"
}

variable "bucket_prefix" {
  type        = string
  description = "Prefix for the bucket name. A random suffix is appended so the name is globally unique."
  default     = "ridaa-tf-demo"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{2,40}$", var.bucket_prefix))
    error_message = "bucket_prefix must be 3-41 chars, lowercase letters, numbers and hyphens only."
  }
}

variable "environment" {
  type        = string
  description = "Environment tag (dev / staging / prod)."
  default     = "dev"
}

variable "owner" {
  type        = string
  description = "Owner tag for the bucket."
  default     = "Ridaa Mirza"
}

variable "enable_versioning" {
  type        = bool
  description = "Turn S3 object versioning on or off."
  default     = true
}

variable "force_destroy" {
  type        = bool
  description = "Allow terraform destroy to delete the bucket even if it still has objects in it."
  default     = true
}
