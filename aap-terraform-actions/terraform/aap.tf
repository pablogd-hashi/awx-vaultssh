# -----------------------------------------------------------------------------
# AAP Action Configuration
#
# This file defines the Terraform Action that triggers AAP after VM creation.
# Terraform Actions (introduced in v1.14) provide a declarative way to run
# non-CRUD operations as part of infrastructure workflows.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AAP Job Launch Action
#
# This action triggers an AAP job template after the VM is created.
# It passes the VM's IP address as an extra variable so AAP knows where to
# connect.
#
# The action:
# - Is triggered by the terraform_data.aap_trigger lifecycle events
# - Waits for the AAP job to complete before Terraform continues
# - Can be manually invoked: terraform apply -invoke action.aap_job_launch.configure_vm
# -----------------------------------------------------------------------------

action "aap_job_launch" "configure_vm" {
  config {
    # The AAP job template to run
    job_template_id = var.aap_job_template_id

    # Wait for the job to complete before continuing
    # Set to false if you want fire-and-forget behavior
    wait_for_completion = true

    # Extra variables passed to the AAP job
    # These are available in your Ansible playbook as regular variables
    # Note: vault_approle_role_id and vault_approle_secret_id are injected by AAP credential lookup
    extra_vars = jsonencode({
      # Target host(s) - the IP address of the newly created VM
      target_hosts = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip

      # SSH user for connecting to the VM
      ssh_user = var.ssh_user

      # Vault configuration for SSH CA
      vault_addr     = var.vault_addr
      vault_ssh_role = var.vault_ssh_role

      # Application configuration
      streamlit_port = var.streamlit_port

      # Metadata about the deployment
      deployment_id = google_compute_instance.vm.instance_id
      created_by    = "terraform-actions"
    })
  }
}

# -----------------------------------------------------------------------------
# Alternative: Direct AAP Inventory Host Creation
#
# If you want Terraform to also create the host in AAP's inventory,
# you can use the aap_host resource. This is optional - you might prefer
# to have your playbook handle dynamic inventory instead.
# -----------------------------------------------------------------------------

# resource "aap_host" "vm" {
#   name         = var.vm_name
#   inventory_id = var.aap_inventory_id
#   variables = jsonencode({
#     ansible_host = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
#     ansible_user = var.ssh_user
#   })
# }

# -----------------------------------------------------------------------------
# Optional: Pre-destroy Action
#
# You can also define actions that run before a resource is destroyed.
# This is useful for graceful shutdown, deregistration, etc.
# -----------------------------------------------------------------------------

# action "aap_job_launch" "cleanup_vm" {
#   config {
#     job_template_id     = var.aap_cleanup_template_id
#     wait_for_completion = true
#     extra_vars = jsonencode({
#       target_host   = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
#       deployment_id = google_compute_instance.vm.instance_id
#     })
#   }
# }
#
# Add this to terraform_data.aap_trigger lifecycle:
#   action_trigger {
#     events  = [before_destroy]
#     actions = [action.aap_job_launch.cleanup_vm]
#   }
