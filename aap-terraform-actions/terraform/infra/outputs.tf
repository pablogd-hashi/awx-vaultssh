# Outputs

# -----------------------------------------------------------------------------
# Compute Outputs
# -----------------------------------------------------------------------------

output "vm_ips" {
  description = "External IP addresses of the VMs"
  value       = module.vm.public_ips
}

output "vm_count" {
  description = "Number of VMs created"
  value       = var.vm_count
}

output "vault_ssh_command" {
  description = "SSH using Vault CLI with ephemeral keys"
  value       = length(module.vm.public_ips) > 0 ? "vault ssh -role=${local.vault_ssh_role_name} -mode=ca ${var.ssh_user}@${module.vm.public_ips[0]}" : "No VMs"
}

# -----------------------------------------------------------------------------
# Vault AppRole Outputs (for AAP Credential Configuration)
# -----------------------------------------------------------------------------

output "vault_approle_role_id" {
  description = "Vault AppRole role_id - use this in AAP Vault Secret Lookup credential"
  value       = local.vault_approle_role_id
}

output "vault_approle_secret_id" {
  description = "Vault AppRole secret_id - use this in AAP Vault Secret Lookup credential"
  value       = local.vault_approle_secret_id
  sensitive   = true
}

output "vault_ssh_role_name" {
  description = "Vault SSH role name for certificate issuance"
  value       = local.vault_ssh_role_name
}
