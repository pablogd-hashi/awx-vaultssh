# -----------------------------------------------------------------------------
# Packer Variables - AAP Controller Image
# -----------------------------------------------------------------------------

# AWS Configuration
variable "aws_region" {
  type        = string
  description = "AWS region to build the AMI"
  default     = "us-east-1"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for building (needs 4+ vCPUs for AAP)"
  default     = "t3.xlarge"
}

variable "disk_size" {
  type        = number
  description = "Root volume size in GB"
  default     = 100
}

# Image naming
variable "ami_name_prefix" {
  type        = string
  description = "Prefix for the AMI name"
  default     = "rhel9-aap-controller"
}

# AAP Configuration
variable "aap_version" {
  type        = string
  description = "AAP version being installed"
  default     = "2.5"
}

variable "aap_setup_bundle_path" {
  type        = string
  description = "Local path to AAP setup bundle tar.gz"
  default     = ""
}

variable "aap_admin_password" {
  type        = string
  description = "Admin password for AAP web UI"
  default     = "ansible123!"
  sensitive   = true
}

variable "aap_hostname" {
  type        = string
  description = "Hostname for AAP services"
  default     = "aap.local"
}

# Optional Vault SSH CA
variable "vault_ssh_ca_public_key" {
  type        = string
  description = "Vault SSH CA public key (optional)"
  default     = ""
  sensitive   = true
}
