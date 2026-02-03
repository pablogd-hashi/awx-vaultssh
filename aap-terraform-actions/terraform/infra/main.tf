# -----------------------------------------------------------------------------
# Infrastructure - Main Configuration
# -----------------------------------------------------------------------------
# Deploys VMs with Vault SSH CA and configures AAP to manage them.
#
# Credential Options:
#   Option A: Vault Signed SSH
#     - Static SSH key stored in AAP
#     - Key is signed by Vault CA before each connection via /ssh/sign
#     - Simpler setup, key persists in AAP
#
#   Option B: Vault Secrets Lookup (Ephemeral)
#     - No static keys stored
#     - Generates ephemeral key pair on-demand via /ssh/issue
#     - Maximum security, zero persistent credentials
#
# Prerequisites in AAP:
#   - "HashiCorp Vault Signed SSH" credential type (Option A)
#   - "HashiCorp Vault Secret Lookup" credential type (Option B)
#   See: docs/aap-prerequisites.md
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Vault SSH CA Module
# -----------------------------------------------------------------------------

module "vault_ssh_ca" {
  source = "../modules/vault-ssh-ca"

  ssh_mount_path    = var.vault_ssh_mount_path
  ssh_role_name     = var.vault_ssh_role
  approle_path      = var.vault_approle_path
  approle_role_name = "aap-${var.vm_name_prefix}"

  allowed_users      = [var.ssh_user]
  default_user       = var.ssh_user
  default_ttl        = "30m"
  max_ttl            = "24h"
  allow_user_key_ids = true

  # Option B (ephemeral) requires key generation capability
  allow_key_generation = var.credential_option == "B"
}

# -----------------------------------------------------------------------------
# VM Module
# -----------------------------------------------------------------------------

module "vm" {
  source = "../modules/vm"

  name_prefix         = var.vm_name_prefix
  instance_count      = var.vm_instance_count
  instance_type       = var.vm_instance_type
  ami_id              = var.vm_ami_id
  ami_name_filter     = var.vm_ami_name_filter
  vpc_id              = var.vpc_id
  subnet_id           = var.subnet_id
  associate_public_ip = true
  allowed_ssh_cidrs   = var.allowed_ssh_cidrs
  ssh_user            = var.ssh_user
  root_volume_size    = 20

  tags = var.tags
}

# -----------------------------------------------------------------------------
# Static SSH Key (Option A only)
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh" {
  count     = var.credential_option == "A" ? 1 : 0
  algorithm = "ED25519"
}

# -----------------------------------------------------------------------------
# AAP Organization Data Source
# -----------------------------------------------------------------------------

data "aap_organization" "main" {
  name = var.aap_organization
}

# -----------------------------------------------------------------------------
# AAP Inventory
# -----------------------------------------------------------------------------

resource "aap_inventory" "main" {
  name            = var.aap_inventory_name
  organization_id = data.aap_organization.main.id
  description     = "Managed VMs with Vault SSH CA authentication"
}

# -----------------------------------------------------------------------------
# AAP Hosts
# -----------------------------------------------------------------------------

resource "aap_host" "vm" {
  for_each = module.vm.inventory

  inventory_id = aap_inventory.main.id
  name         = each.key
  variables = jsonencode({
    ansible_host = each.value.ansible_host
    ansible_user = each.value.ansible_user
    instance_id  = each.value.instance_id
  })
}

# -----------------------------------------------------------------------------
# AAP Credentials - Option A (Vault Signed SSH)
# -----------------------------------------------------------------------------
# Static SSH key stored in AAP, signed by Vault CA before each connection.
# Uses the "HashiCorp Vault Signed SSH" credential type.

resource "aap_credential" "vault_signed_ssh" {
  count = var.credential_option == "A" ? 1 : 0

  name            = "${var.vm_name_prefix}-vault-signed-ssh"
  organization_id = data.aap_organization.main.id
  credential_type = "HashiCorp Vault Signed SSH"

  inputs = jsonencode({
    vault_addr      = var.vault_address
    vault_namespace = var.vault_namespace
    role_id         = module.vault_ssh_ca.approle_role_id
    secret_id       = module.vault_ssh_ca.approle_secret_id
    ssh_key_data    = tls_private_key.ssh[0].private_key_openssh
    public_key_data = tls_private_key.ssh[0].public_key_openssh
    ssh_mount_point = var.vault_ssh_mount_path
    role            = var.vault_ssh_role
  })
}

# -----------------------------------------------------------------------------
# AAP Credentials - Option B (Vault Secrets Lookup - Ephemeral)
# -----------------------------------------------------------------------------
# Generates ephemeral SSH key pairs on-demand via /ssh/issue endpoint.
# Uses the "HashiCorp Vault Secret Lookup" credential type as source.

resource "aap_credential" "vault_lookup" {
  count = var.credential_option == "B" ? 1 : 0

  name            = "${var.vm_name_prefix}-vault-lookup"
  organization_id = data.aap_organization.main.id
  credential_type = "HashiCorp Vault Secret Lookup"

  inputs = jsonencode({
    vault_addr      = var.vault_address
    vault_namespace = var.vault_namespace
    auth_path       = var.vault_approle_path
    role_id         = module.vault_ssh_ca.approle_role_id
    secret_id       = module.vault_ssh_ca.approle_secret_id
  })
}

resource "aap_credential" "machine_ephemeral" {
  count = var.credential_option == "B" ? 1 : 0

  name            = "${var.vm_name_prefix}-ephemeral-ssh"
  organization_id = data.aap_organization.main.id
  credential_type = "Machine"

  inputs = jsonencode({
    username = var.ssh_user
  })

  # Link to Vault lookup for dynamic SSH key injection
  input_sources {
    source_credential_id = aap_credential.vault_lookup[0].id
    input_field_name     = "ssh_key_data"
    target               = "ssh_key_data"
    metadata = jsonencode({
      secret_path    = "${var.vault_ssh_mount_path}/issue/${var.vault_ssh_role}"
      secret_key     = "private_key"
      secret_backend = "ssh"
    })
  }
}

# -----------------------------------------------------------------------------
# AAP Project
# -----------------------------------------------------------------------------

resource "aap_project" "main" {
  name            = var.aap_project_name
  organization_id = data.aap_organization.main.id
  scm_type        = "git"
  scm_url         = var.aap_project_scm_url
  scm_branch      = var.aap_project_scm_branch
}

# -----------------------------------------------------------------------------
# AAP Job Template
# -----------------------------------------------------------------------------

resource "aap_job_template" "configure_vm" {
  name            = var.aap_job_template_name
  organization_id = data.aap_organization.main.id
  project_id      = aap_project.main.id
  inventory_id    = aap_inventory.main.id
  playbook        = var.aap_playbook

  # Credentials depend on selected option
  credential_ids = var.credential_option == "A" ? [
    aap_credential.vault_signed_ssh[0].id
    ] : [
    aap_credential.vault_lookup[0].id,
    aap_credential.machine_ephemeral[0].id
  ]
}

# -----------------------------------------------------------------------------
# Terraform Action - Auto-configure VMs on Create/Update
# -----------------------------------------------------------------------------
# Triggers AAP job when VM module resources change.
# Requires Terraform 1.14+ for Actions support.

action "aap_configure" "vm" {
  triggers = {
    action_trigger = {
      events = ["create", "update"]
      condition = {
        resources = [module.vm]
      }
    }
  }

  run {
    resource "aap_job" "configure" {
      job_template_id = aap_job_template.configure_vm.id
      inventory_id    = aap_inventory.main.id

      extra_vars = jsonencode({
        target_hosts    = keys(module.vm.inventory)
        credential_type = var.credential_option == "A" ? "signed_ssh" : "ephemeral"
        vault_ssh_mount = var.vault_ssh_mount_path
        vault_ssh_role  = var.vault_ssh_role
      })

      wait_for_completion = true
      timeout             = 600
    }
  }

  depends_on = [
    aap_host.vm,
    aap_job_template.configure_vm
  ]
}
