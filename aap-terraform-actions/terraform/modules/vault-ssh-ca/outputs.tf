# Vault SSH CA Module - Outputs

output "ca_public_key" {
  description = "SSH CA public key"
  value       = local.vault_ca_public_key
}

output "approle_role_id" {
  description = "AppRole role ID"
  value       = local.vault_approle_role_id
  sensitive   = true
}

output "approle_secret_id" {
  description = "AppRole secret ID"
  value       = local.vault_approle_secret_id
  sensitive   = true
}

output "ssh_role_name" {
  description = "SSH role name"
  value       = local.vault_ssh_role_name
}
