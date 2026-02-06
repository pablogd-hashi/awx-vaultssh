# -----------------------------------------------------------------------------
# Variables - VM Module
# -----------------------------------------------------------------------------

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only alphanumeric characters and hyphens."
  }
}

variable "instance_count" {
  description = "Number of VM instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 20
    error_message = "instance_count must be between 1 and 20."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID (leave empty to use ami_name_filter)"
  type        = string
  default     = ""
}

variable "ami_name_filter" {
  description = "AMI name filter for golden image lookup"
  type        = string
  default     = "rhel9-vault-ssh-ca-*"
}

variable "vpc_id" {
  description = "VPC ID for deployment"
  type        = string

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_id))
    error_message = "vpc_id must be a valid VPC ID (vpc-xxxxxxxx)."
  }
}

variable "subnet_id" {
  description = "Subnet ID for deployment"
  type        = string

  validation {
    condition     = can(regex("^subnet-[a-f0-9]+$", var.subnet_id))
    error_message = "subnet_id must be a valid Subnet ID (subnet-xxxxxxxx)."
  }
}

variable "associate_public_ip" {
  description = "Associate public IP address with instances"
  type        = bool
  default     = true
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH (empty = no SSH access)"
  type        = list(string)
  default     = []
}

variable "ssh_user" {
  description = "SSH username for the golden image"
  type        = string
  default     = "ansible"

  validation {
    condition     = length(var.ssh_user) > 0
    error_message = "ssh_user cannot be empty."
  }
}

variable "app_port" {
  description = "Application port to expose (0 to disable)"
  type        = number
  default     = 0

  validation {
    condition     = var.app_port >= 0 && var.app_port <= 65535
    error_message = "app_port must be between 0 and 65535."
  }
}

variable "root_volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "root_volume_size must be between 8 and 1000 GB."
  }
}

variable "tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
