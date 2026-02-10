# Variables

# -----------------------------------------------------------------------------
# AAP (required)
# -----------------------------------------------------------------------------

variable "aap_host" {
  description = "AAP controller URL"
  type        = string
}

variable "aap_username" {
  description = "AAP username"
  type        = string
  default     = "admin"
}

variable "aap_password" {
  description = "AAP password"
  type        = string
  sensitive   = true
}

variable "aap_job_template_id" {
  description = "AAP job template ID"
  type        = number
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
  default     = "ec2-user"
}

# -----------------------------------------------------------------------------
# Vault (required)
# -----------------------------------------------------------------------------

variable "vault_addr" {
  description = "Vault address"
  type        = string
}

variable "vault_token" {
  description = "Vault token"
  type        = string
  sensitive   = true
}

variable "vault_namespace" {
  description = "Vault namespace (empty for OSS)"
  type        = string
  default     = ""
}

variable "vault_ssh_mount" {
  description = "Vault SSH mount path"
  type        = string
  default     = "ssh"
}

variable "vault_ssh_role" {
  description = "Vault SSH role name"
  type        = string
  default     = "aap-ssh"
}

# -----------------------------------------------------------------------------
# AWS
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Resource name prefix"
  type        = string
  default     = "vault-ssh-demo"
}

variable "vpc_cidr" {
  description = "VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vm_count" {
  description = "Number of VMs"
  type        = number
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "ami_filter" {
  description = "AMI name filter"
  type        = string
  default     = "rhel9-vault-ssh-ca-*"
}

variable "allowed_cidrs" {
  description = "CIDRs allowed SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
