# -----------------------------------------------------------------------------
# Variables - Infrastructure
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Credential Option
# -----------------------------------------------------------------------------

variable "credential_option" {
  description = "Credential option: A (Vault Signed SSH) or B (Vault Secrets Lookup - ephemeral)"
  type        = string
  default     = "A"

  validation {
    condition     = contains(["A", "B"], var.credential_option)
    error_message = "credential_option must be 'A' (signed SSH) or 'B' (ephemeral keys)."
  }
}

# -----------------------------------------------------------------------------
# AAP Configuration (from terraform/aap outputs)
# -----------------------------------------------------------------------------

variable "aap_host" {
  description = "AAP controller URL (e.g., https://1.2.3.4)"
  type        = string
}

variable "aap_username" {
  description = "AAP admin username"
  type        = string
  default     = "admin"
}

variable "aap_password" {
  description = "AAP admin password"
  type        = string
  sensitive   = true
}

variable "aap_organization" {
  description = "AAP organization name (must exist in AAP)"
  type        = string
  default     = "Default"
}

variable "aap_project_name" {
  description = "AAP project name for playbooks"
  type        = string
  default     = "vault-ssh-demo"
}

variable "aap_project_scm_url" {
  description = "Git repository URL for AAP project"
  type        = string
  default     = "https://github.com/hashicorp-education/learn-vault-ssh-ca-ansible"
}

variable "aap_project_scm_branch" {
  description = "Git branch for AAP project"
  type        = string
  default     = "main"
}

variable "aap_inventory_name" {
  description = "AAP inventory name"
  type        = string
  default     = "vault-ssh-hosts"
}

variable "aap_job_template_name" {
  description = "AAP job template name"
  type        = string
  default     = "configure-vm"
}

variable "aap_playbook" {
  description = "Playbook path within the project"
  type        = string
  default     = "playbooks/configure.yml"
}

# -----------------------------------------------------------------------------
# Vault Configuration
# -----------------------------------------------------------------------------

variable "vault_address" {
  description = "Vault server address (e.g., https://vault.example.com:8200)"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (for HCP Vault, leave empty for OSS)"
  type        = string
  default     = ""
}

variable "vault_ssh_mount_path" {
  description = "Vault SSH secrets engine mount path"
  type        = string
  default     = "ssh"
}

variable "vault_ssh_role" {
  description = "Vault SSH signing role name"
  type        = string
  default     = "aap-ssh"
}

variable "vault_approle_path" {
  description = "Vault AppRole auth mount path"
  type        = string
  default     = "approle"
}

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC ID for VM deployment (use AAP VPC or existing)"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for VM deployment (must be public for SSH access)"
  type        = string
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "vm_name_prefix" {
  description = "Name prefix for VM resources"
  type        = string
  default     = "vault-ssh-demo"
}

variable "vm_instance_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 1

  validation {
    condition     = var.vm_instance_count >= 1 && var.vm_instance_count <= 10
    error_message = "vm_instance_count must be between 1 and 10."
  }
}

variable "vm_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "vm_ami_id" {
  description = "Specific AMI ID (leave empty to use ami_name_filter)"
  type        = string
  default     = ""
}

variable "vm_ami_name_filter" {
  description = "AMI name filter for golden image lookup (built by Packer)"
  type        = string
  default     = "rhel9-vault-ssh-ca-*"
}

variable "ssh_user" {
  description = "SSH username on target VMs (must match golden image configuration)"
  type        = string
  default     = "ansible"
}

variable "allowed_ssh_cidrs" {
  description = "CIDR blocks allowed to SSH to VMs (restrict in production)"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project   = "vault-ssh-demo"
    ManagedBy = "terraform"
  }
}
