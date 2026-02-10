# Ansible Automation Platform Integration
#
# Terraform Actions trigger AAP job after VM creation.
# AAP configures the instances (Day-2 configuration).
#
# The playbook uses Vault SSH CA for ephemeral credentials:
#   1. AAP injects AppRole credentials via Vault Credential (env vars)
#   2. Playbook authenticates to Vault via AppRole
#   3. Vault issues ephemeral SSH private key + signed certificate via /ssh/issue
#   4. Playbook connects to VMs using Vault-signed credentials
#   5. Credentials are shredded after use
#
# Security:
#   - AppRole credentials stored in AAP credential store (not in extra_vars/logs)
#   - No static SSH keys stored anywhere
#   - Ephemeral keys generated per run and shredded after use

action "aap_job_launch" "configure_vm" {
  config {
    job_template_id     = var.aap_job_template_id
    wait_for_completion = false

    # Only non-sensitive variables passed here
    # AppRole credentials come from AAP Vault Credential (VAULT_ROLE_ID, VAULT_SECRET_ID)
    extra_vars = jsonencode({
      target_hosts    = join(",", module.vm.public_ips)
      ssh_user        = var.ssh_user
      vault_addr      = var.vault_addr
      vault_namespace = var.vault_namespace
      vault_ssh_role  = local.vault_ssh_role_name
    })
  }
}
