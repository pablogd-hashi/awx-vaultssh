# -----------------------------------------------------------------------------
# Outputs - Infrastructure
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VM Outputs
# -----------------------------------------------------------------------------

output "vm_instance_ids" {
  description = "EC2 instance IDs"
  value       = module.vm.instance_ids
}

output "vm_public_ips" {
  description = "Public IP addresses of VMs"
  value       = module.vm.public_ips
}

output "vm_private_ips" {
  description = "Private IP addresses of VMs"
  value       = module.vm.private_ips
}

output "vm_ssh_user" {
  description = "SSH username for VMs"
  value       = module.vm.ssh_user
}

output "vm_ami_id" {
  description = "AMI ID used for VMs"
  value       = module.vm.ami_id
}

# -----------------------------------------------------------------------------
# Vault Outputs
# -----------------------------------------------------------------------------

output "vault_ssh_ca_public_key" {
  description = "Vault SSH CA public key (for TrustedUserCAKeys)"
  value       = module.vault_ssh_ca.ca_public_key
  sensitive   = true
}

output "vault_ssh_mount_path" {
  description = "Vault SSH secrets engine mount path"
  value       = module.vault_ssh_ca.ssh_mount_path
}

output "vault_ssh_role" {
  description = "Vault SSH signing role"
  value       = module.vault_ssh_ca.ssh_role_name
}

output "vault_approle_role_id" {
  description = "Vault AppRole role ID"
  value       = module.vault_ssh_ca.approle_role_id
  sensitive   = true
}

# -----------------------------------------------------------------------------
# AAP Outputs
# -----------------------------------------------------------------------------

output "aap_inventory_id" {
  description = "AAP inventory ID"
  value       = aap_inventory.main.id
}

output "aap_job_template_id" {
  description = "AAP job template ID"
  value       = aap_job_template.configure_vm.id
}

output "credential_option" {
  description = "Credential option in use (A=signed SSH, B=ephemeral)"
  value       = var.credential_option
}

output "credential_option_description" {
  description = "Human-readable credential option description"
  value       = var.credential_option == "A" ? "Vault Signed SSH (static key)" : "Vault Secrets Lookup (ephemeral keys)"
}

# -----------------------------------------------------------------------------
# Connection Info
# -----------------------------------------------------------------------------

output "ssh_command_example" {
  description = "Example SSH command (requires Vault-signed certificate)"
  value       = length(module.vm.public_ips) > 0 ? "ssh -i ~/.ssh/id_ed25519 ${var.ssh_user}@${module.vm.public_ips[0]}" : "No VMs deployed"
}

output "inventory_json" {
  description = "VM inventory in JSON format (for debugging)"
  value       = module.vm.inventory
}
