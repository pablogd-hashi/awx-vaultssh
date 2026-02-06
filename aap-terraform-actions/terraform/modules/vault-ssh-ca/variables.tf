# Vault SSH CA Module - Variables

variable "ssh_mount_path" {
  description = "SSH secrets engine mount path"
  type        = string
  default     = "ssh"
}

variable "ssh_role_name" {
  description = "SSH role name"
  type        = string
  default     = "aap-ssh"
}

variable "allowed_users" {
  description = "Allowed SSH users"
  type        = list(string)
  default     = ["ansible"]
}

variable "default_user" {
  description = "Default SSH user"
  type        = string
  default     = "ansible"
}

variable "default_ttl" {
  description = "Default certificate TTL"
  type        = string
  default     = "1800"
}

variable "max_ttl" {
  description = "Max certificate TTL"
  type        = string
  default     = "86400"
}

variable "approle_role_name" {
  description = "AppRole role name"
  type        = string
  default     = "aap-ssh"
}
