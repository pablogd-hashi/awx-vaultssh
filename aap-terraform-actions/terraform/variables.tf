# -----------------------------------------------------------------------------
# GCP Configuration
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the VM"
  type        = string
  default     = "us-central1-a"
}

# -----------------------------------------------------------------------------
# Vault Configuration
# -----------------------------------------------------------------------------

variable "vault_addr" {
  description = "Vault server address"
  type        = string
}

variable "vault_namespace" {
  description = "Vault namespace (empty for OSS, 'admin' for HCP Vault)"
  type        = string
  default     = ""
}

variable "vault_ssh_path" {
  description = "Path to the SSH secrets engine in Vault"
  type        = string
  default     = "ssh-client-signer"
}

variable "vault_ssh_role" {
  description = "Vault SSH signing role name"
  type        = string
  default     = "aap-role"
}

# -----------------------------------------------------------------------------
# AAP Configuration
# -----------------------------------------------------------------------------

variable "aap_host" {
  description = "Ansible Automation Platform host URL"
  type        = string
}

variable "aap_token" {
  description = "AAP API token for authentication"
  type        = string
  sensitive   = true
}

variable "aap_job_template_id" {
  description = "AAP job template ID for VM configuration"
  type        = number
}

variable "aap_organization_id" {
  description = "AAP organization ID"
  type        = number
  default     = 1
}

# -----------------------------------------------------------------------------
# VM Configuration
# -----------------------------------------------------------------------------

variable "vm_name" {
  description = "Name of the VM to create"
  type        = string
  default     = "vault-ssh-demo"
}

variable "machine_type" {
  description = "GCP machine type"
  type        = string
  default     = "e2-medium"
}

variable "ssh_user" {
  description = "SSH username for connecting to the VM"
  type        = string
  default     = "rhel"
}

variable "os_image" {
  description = "OS image for the VM"
  type        = string
  default     = "rhel-cloud/rhel-9"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "vault-ssh-demo-network"
}

variable "subnet_cidr" {
  description = "Subnet CIDR range"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_ssh_ranges" {
  description = "CIDR ranges allowed to SSH to the VM"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Restrict this in production!
}

# -----------------------------------------------------------------------------
# Application Configuration
# -----------------------------------------------------------------------------

variable "streamlit_port" {
  description = "Port for the Streamlit demo application"
  type        = number
  default     = 8501
}
