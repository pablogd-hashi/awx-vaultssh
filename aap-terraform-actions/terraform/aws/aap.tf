# -----------------------------------------------------------------------------
# AAP Configuration and Job Trigger
#
# This file:
#   1. Looks up AAP inventory and job template
#   2. Creates hosts in AAP inventory
#   3. Triggers AAP job via Terraform Actions
#
# Two credential modes supported:
#   Option A: Vault Secrets Lookup - passes AppRole creds, AAP fetches ephemeral keys
#   Option B: Vault Signed SSH - passes AppRole creds, AAP signs static key
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AAP Data Sources
# -----------------------------------------------------------------------------

data "aap_inventory" "main" {
  name              = var.aap_inventory_name
  organization_name = var.aap_organization_name
}

data "aap_job_template" "configure_vm" {
  name              = var.aap_job_template_name
  organization_name = var.aap_organization_name
}

# -----------------------------------------------------------------------------
# AAP Hosts
# -----------------------------------------------------------------------------

resource "aap_host" "vm" {
  count = var.vm_count

  inventory_id = data.aap_inventory.main.id
  name         = "${var.resource_prefix}-vm-${count.index + 1}"
  description  = "EC2 instance ${aws_instance.vm[count.index].id} - ${aws_instance.vm[count.index].public_ip}"

  variables = jsonencode({
    ansible_host = aws_instance.vm[count.index].public_ip
    ansible_user = var.ssh_user
  })

  # Trigger AAP job after host creation
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vm]
    }
  }

  depends_on = [
    aws_instance.vm,
  ]
}

# -----------------------------------------------------------------------------
# AAP Job Launch Action
#
# Triggered automatically after hosts are created/updated.
# Passes all necessary Vault credentials via extra_vars.
# -----------------------------------------------------------------------------

action "aap_job_launch" "configure_vm" {
  config {
    job_template_id     = data.aap_job_template.configure_vm.id
    wait_for_completion = true

    # All credentials passed directly - no AAP credential configuration needed!
    extra_vars = jsonencode({
      # Target hosts (comma-separated for multiple)
      target_hosts = join(",", local.vm_ips)

      # SSH user for connecting
      ssh_user = var.ssh_user

      # Vault configuration
      vault_addr      = var.vault_addr
      vault_namespace = var.vault_namespace
      vault_ssh_mount = var.vault_ssh_mount_path
      vault_ssh_role  = local.vault_ssh_role_name

      # Vault AppRole credentials (for both Option A and B)
      vault_approle_role_id   = local.vault_approle_role_id
      vault_approle_secret_id = local.vault_approle_secret_id

      # Credential option: "A" = ephemeral keys, "B" = signed SSH
      credential_option = var.credential_option

      # Application configuration
      app_port = var.app_port

      # Deployment metadata
      deployment_id = join(",", local.vm_ids)
      created_by    = "terraform-actions"
      environment   = var.environment
    })
  }
}

# -----------------------------------------------------------------------------
# Alternative: Manual Job Trigger
#
# If you need to re-run the job without changing infrastructure:
#   terraform apply -invoke action.aap_job_launch.configure_vm
# -----------------------------------------------------------------------------
