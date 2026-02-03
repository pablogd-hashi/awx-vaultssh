# -----------------------------------------------------------------------------
# Variables - Vault SSH CA Module
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SSH Secrets Engine
# -----------------------------------------------------------------------------

variable "ssh_mount_path" {
  description = "Mount path for SSH secrets engine"
  type        = string
  default     = "ssh"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.ssh_mount_path))
    error_message = "ssh_mount_path must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "ssh_role_name" {
  description = "Name for the SSH signing role"
  type        = string
  default     = "aap-ssh"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.ssh_role_name))
    error_message = "ssh_role_name must contain only alphanumeric characters, hyphens, and underscores."
  }
}

# -----------------------------------------------------------------------------
# Certificate Settings
# -----------------------------------------------------------------------------

variable "allowed_users" {
  description = "List of allowed SSH users for certificate signing"
  type        = list(string)
  default     = ["ansible"]

  validation {
    condition     = length(var.allowed_users) > 0
    error_message = "allowed_users must contain at least one user."
  }
}

variable "default_user" {
  description = "Default SSH user for certificates"
  type        = string
  default     = "ansible"

  validation {
    condition     = length(var.default_user) > 0
    error_message = "default_user cannot be empty."
  }
}

variable "default_ttl" {
  description = "Default certificate TTL (e.g., '30m', '1h', '24h')"
  type        = string
  default     = "30m"

  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.default_ttl))
    error_message = "default_ttl must be a valid duration (e.g., '30m', '1h')."
  }
}

variable "max_ttl" {
  description = "Maximum certificate TTL (e.g., '1h', '24h')"
  type        = string
  default     = "24h"

  validation {
    condition     = can(regex("^[0-9]+[smh]$", var.max_ttl))
    error_message = "max_ttl must be a valid duration (e.g., '1h', '24h')."
  }
}

variable "allow_user_key_ids" {
  description = "Allow user-specified key IDs in certificates"
  type        = bool
  default     = true
}

variable "allow_key_generation" {
  description = "Enable key generation for /ssh/issue endpoint (required for Option B ephemeral keys)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# AppRole Auth
# -----------------------------------------------------------------------------

variable "approle_path" {
  description = "AppRole auth mount path"
  type        = string
  default     = "approle"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.approle_path))
    error_message = "approle_path must contain only alphanumeric characters, hyphens, and underscores."
  }
}

variable "approle_role_name" {
  description = "AppRole role name for AAP"
  type        = string
  default     = "aap-ssh"

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]+$", var.approle_role_name))
    error_message = "approle_role_name must contain only alphanumeric characters, hyphens, and underscores."
  }
}
