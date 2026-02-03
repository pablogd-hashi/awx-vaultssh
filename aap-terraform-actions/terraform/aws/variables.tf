# -----------------------------------------------------------------------------
# Variables - AWS Infrastructure with Vault SSH CA
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "resource_prefix" {
  description = "Prefix for AWS resource names"
  type        = string
  default     = "vault-ssh-aap"
}

# -----------------------------------------------------------------------------
# Vault Configuration
# -----------------------------------------------------------------------------

variable "vault_addr" {
  description = "Vault server address"
  type        = string
}

variable "vault_token" {
  description = "Vault admin token for provisioning resources"
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Vault namespace (empty for OSS, 'admin' for HCP Vault)"
  type        = string
  default     = ""
}

variable "vault_skip_tls_verify" {
  description = "Skip TLS verification for Vault (not recommended for production)"
  type        = bool
  default     = false
}

variable "vault_ssh_mount_path" {
  description = "Path for the SSH secrets engine in Vault"
  type        = string
  default     = "ssh"
}

variable "vault_ssh_role" {
  description = "Vault SSH role name for certificate signing"
  type        = string
  default     = "aap-ssh"
}

# -----------------------------------------------------------------------------
# AAP Configuration
# -----------------------------------------------------------------------------

variable "aap_host" {
  description = "Ansible Automation Platform host URL"
  type        = string
}

variable "aap_username" {
  description = "AAP username for authentication"
  type        = string
}

variable "aap_password" {
  description = "AAP password for authentication"
  type        = string
  sensitive   = true
}

variable "aap_job_template_name" {
  description = "AAP job template name for VM configuration"
  type        = string
  default     = "vault-ssh-configure"
}

variable "aap_inventory_name" {
  description = "AAP inventory name"
  type        = string
  default     = "vault-ssh-inventory"
}

variable "aap_organization_name" {
  description = "AAP organization name"
  type        = string
  default     = "Default"
}

# -----------------------------------------------------------------------------
# Credential Option Configuration
# -----------------------------------------------------------------------------

variable "credential_option" {
  description = "SSH credential option: 'A' for Vault Secrets Lookup (ephemeral keys), 'B' for Vault Signed SSH (static key)"
  type        = string
  default     = "A"

  validation {
    condition     = contains(["A", "B"], var.credential_option)
    error_message = "credential_option must be 'A' (ephemeral keys) or 'B' (signed SSH)."
  }
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_id" {
  description = "AMI ID for the VM (leave empty to use latest golden image)"
  type        = string
  default     = ""
}

variable "ami_name_filter" {
  description = "AMI name filter to find the golden image"
  type        = string
  default     = "rhel9-vault-ssh-ca-*"
}

variable "ssh_user" {
  description = "SSH username for connecting to VMs"
  type        = string
  default     = "ansible"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to VMs"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Application Configuration (Optional)
# -----------------------------------------------------------------------------

variable "app_port" {
  description = "Application port (if deploying an app)"
  type        = number
  default     = 8501
}
