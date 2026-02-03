# -----------------------------------------------------------------------------
# Variables - AAP Controller Deployment
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for deployment (must have pre-built AAP AMI)"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "eu-central-1", "ap-southeast-1", "ap-south-1"], var.aws_region)
    error_message = "Region must be one of: us-east-1, eu-central-1, ap-southeast-1, ap-south-1 (pre-built AMIs available)."
  }
}

variable "instance_type" {
  description = "EC2 instance type for AAP controller (minimum m6a.xlarge recommended)"
  type        = string
  default     = "m6a.xlarge"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "aap"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only alphanumeric characters and hyphens."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB (minimum 100 recommended for AAP)"
  type        = number
  default     = 100

  validation {
    condition     = var.root_volume_size >= 50
    error_message = "root_volume_size must be at least 50 GB for AAP."
  }
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to AAP (restrict in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_ssh_cidrs) > 0
    error_message = "allowed_ssh_cidrs must contain at least one CIDR block."
  }
}

variable "allowed_https_cidrs" {
  description = "CIDR blocks allowed to access AAP HTTPS (restrict in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.allowed_https_cidrs) > 0
    error_message = "allowed_https_cidrs must contain at least one CIDR block."
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
