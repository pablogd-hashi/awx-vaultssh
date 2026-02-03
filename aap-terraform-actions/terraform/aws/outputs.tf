# -----------------------------------------------------------------------------
# Terraform Outputs
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# VM Outputs
# -----------------------------------------------------------------------------

output "vm_ids" {
  description = "EC2 instance IDs"
  value       = local.vm_ids
}

output "vm_public_ips" {
  description = "Public IP addresses of VMs"
  value       = local.vm_ips
}

output "vm_names" {
  description = "Names of VMs"
  value       = local.vm_names
}

# -----------------------------------------------------------------------------
# Vault Outputs
# -----------------------------------------------------------------------------

output "vault_ssh_ca_public_key" {
  description = "Vault SSH CA public key (for manual configuration if needed)"
  value       = local.vault_ca_public_key
  sensitive   = true
}

output "vault_approle_role_id" {
  description = "Vault AppRole Role ID"
  value       = local.vault_approle_role_id
  sensitive   = true
}

output "vault_ssh_role_name" {
  description = "Vault SSH role name"
  value       = local.vault_ssh_role_name
}

# -----------------------------------------------------------------------------
# Network Outputs
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID for VMs"
  value       = aws_security_group.vm.id
}

# -----------------------------------------------------------------------------
# Connection Information
# -----------------------------------------------------------------------------

output "credential_option" {
  description = "SSH credential option being used (A=ephemeral, B=signed)"
  value       = var.credential_option
}

output "ssh_command_example" {
  description = "Example SSH command (requires Vault-issued certificate)"
  value       = length(local.vm_ips) > 0 ? "ssh -i /path/to/private_key -i /path/to/signed_cert.pub ${var.ssh_user}@${local.vm_ips[0]}" : "No VMs created"
}

output "app_urls" {
  description = "Application URLs (if app deployed)"
  value       = [for ip in local.vm_ips : "http://${ip}:${var.app_port}"]
}
