# -----------------------------------------------------------------------------
# Outputs - Vault SSH CA Module
# -----------------------------------------------------------------------------

output "ssh_mount_path" {
  description = "SSH secrets engine mount path"
  value       = vault_mount.ssh.path
}

output "ssh_role_name" {
  description = "SSH signing role name"
  value       = vault_ssh_secret_backend_role.aap.name
}

output "ca_public_key" {
  description = "SSH CA public key (for TrustedUserCAKeys on hosts)"
  value       = vault_ssh_secret_backend_ca.ca.public_key
}

output "approle_path" {
  description = "AppRole auth mount path"
  value       = vault_auth_backend.approle.path
}

output "approle_role_name" {
  description = "AppRole role name"
  value       = vault_approle_auth_backend_role.aap.role_name
}

output "approle_role_id" {
  description = "AppRole role ID for AAP credential"
  value       = data.vault_approle_auth_backend_role_id.aap.role_id
  sensitive   = true
}

output "approle_secret_id" {
  description = "AppRole secret ID for AAP credential"
  value       = vault_approle_auth_backend_role_secret_id.aap.secret_id
  sensitive   = true
}

output "policy_name" {
  description = "Name of the Vault policy"
  value       = vault_policy.aap_ssh.name
}
