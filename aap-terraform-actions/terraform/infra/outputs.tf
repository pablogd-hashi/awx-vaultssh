# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "vm_public_ips" {
  description = "VM public IPs"
  value       = module.vm.public_ips
}

output "ssh_command" {
  description = "SSH command example"
  value       = length(module.vm.public_ips) > 0 ? "ssh ${var.ssh_user}@${module.vm.public_ips[0]}" : "No VMs"
}

output "vault_approle_role_id" {
  description = "Vault AppRole role ID (for AAP credential)"
  value       = module.vault_ssh_ca.approle_role_id
  sensitive   = true
}

output "vault_approle_secret_id" {
  description = "Vault AppRole secret ID (for AAP credential)"
  value       = module.vault_ssh_ca.approle_secret_id
  sensitive   = true
}

output "aap_inventory_id" {
  description = "AAP inventory ID"
  value       = aap_inventory.main.id
}
