# -----------------------------------------------------------------------------
# Packer Variables - Golden VM Image
# -----------------------------------------------------------------------------

variable "vault_ssh_ca_public_key" {
  type        = string
  description = "Vault SSH CA public key (from: vault read -field=public_key ssh/config/ca)"
  sensitive   = true
}

variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI"
  default     = "us-east-1"
}

variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the AMI name"
  default     = "rhel9-vault-ssh-ca"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for building the AMI"
  default     = "t3.micro"
}

variable "ssh_user" {
  type        = string
  description = "SSH user to create for Ansible"
  default     = "ansible"
}

# Optional VPC configuration
variable "vpc_id" {
  type        = string
  description = "VPC ID (uses default VPC if not specified)"
  default     = ""
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID (uses default subnet if not specified)"
  default     = ""
}
