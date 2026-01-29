# AAP with Terraform Actions (Enterprise)

This folder contains a production-ready deployment using **Red Hat Ansible Automation Platform** and **Terraform Actions** to provision VMs with Vault-signed SSH certificates.

## Overview

This approach uses Terraform Actions (introduced in Terraform 1.14) to orchestrate the complete workflow:

1. Terraform provisions a VM in GCP
2. Terraform triggers AAP via Actions after VM creation
3. AAP authenticates to Vault using AppRole
4. Vault issues a short-lived SSH certificate
5. AAP connects to the new VM and installs a demo Streamlit application

## What are Terraform Actions?

Terraform Actions solve a long-standing problem: how do you run non-CRUD operations (like triggering Ansible, invoking a Lambda, or invalidating a cache) as part of your infrastructure workflow?

Before Actions, people used workarounds like `local-exec` provisioners or fake data sources. These were brittle and didn't fit Terraform's mental model.

**Actions are different:**
- They're declared in your Terraform config (not hidden in shell scripts)
- They trigger on resource lifecycle events (`after_create`, `after_update`, `before_destroy`)
- They don't manage state - they just run when needed
- They can be invoked manually: `terraform apply -invoke action.aap_job_launch.configure_vm`

### Why Actions Instead of Resources?

The old approach used an `aap_job` resource:

```hcl
# OLD - Don't use this
resource "aap_job" "configure_vm" {
  job_template_id = var.aap_job_template_id
  extra_vars = jsonencode({ target_host = module.compute.vm_ip })
}
```

**Problems with resources:**
- The job is treated as managed state - Terraform tracks it
- `terraform destroy` tries to "destroy" the job (what does that even mean?)
- Re-running `terraform apply` might re-trigger the job unexpectedly
- The job runs during the plan phase in some providers

**Actions fix all of this** by being explicit triggers, not managed resources.

## Prerequisites

- Terraform 1.14+
- Red Hat Ansible Automation Platform (with API access)
- HashiCorp Vault server with SSH CA configured
- GCP project with appropriate permissions
- AAP credential type `HashiCorp Vault Signed SSH` configured

## Vault Setup

Before deployment, your Vault server must have:

1. **SSH secrets engine enabled** at `ssh-client-signer`
2. **AppRole auth** configured with role `awx-role`
3. **SSH signing role** `awx-role` configured

See `../shared/vault-config/` for the policy and `../docs.md` for full setup instructions.

## Quick Start

### 1. Configure Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
# GCP Configuration
project_id = "your-gcp-project"
region     = "us-central1"
zone       = "us-central1-a"

# AAP Configuration
aap_host            = "https://aap.example.com"
aap_token           = "your-aap-token"
aap_job_template_id = 42

# VM Configuration
ssh_user = "rhel"
```

### 2. Configure AAP Credential

In AAP, create a Machine credential with:
- **Username:** `rhel` (or your VM user)
- **SSH Private Key:** A private key for AAP to use
- **Signed SSH Certificate:** Linked to your Vault credential

The Vault credential should have:
- **Vault URL:** Your Vault server URL
- **Role ID / Secret ID:** AppRole credentials
- **SSH Path:** `ssh-client-signer`
- **Role Name:** `awx-role`

### 3. Deploy

```bash
cd terraform
terraform init
terraform apply
```

### 4. Watch the Magic

Terraform will:
1. Create the VM in GCP
2. Configure firewall rules
3. Trigger the AAP job via Actions
4. AAP will configure the VM with the Streamlit app

You can also manually invoke the action:
```bash
terraform apply -invoke action.aap_job_launch.configure_vm
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT FLOW                               │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Terraform   │────>│     GCP      │────>│   New VM     │
│   Apply      │     │   Compute    │     │  (created)   │
└──────┬───────┘     └──────────────┘     └──────────────┘
       │                                          ▲
       │ after_create                             │
       ▼                                          │
┌──────────────┐     ┌──────────────┐             │
│  TF Action   │────>│     AAP      │             │
│  (trigger)   │     │  Controller  │             │
└──────────────┘     └──────┬───────┘             │
                           │                      │
                           ▼                      │
                    ┌──────────────┐              │
                    │    Vault     │              │
                    │   (SSH CA)   │              │
                    └──────┬───────┘              │
                           │ signed cert          │
                           ▼                      │
                    ┌──────────────┐              │
                    │     AAP      │──────────────┘
                    │  (SSH + run  │
                    │   playbook)  │
                    └──────────────┘
```

## Folder Structure

```
aap-terraform-actions/
├── README.md                    # This file
├── terraform/
│   ├── main.tf                  # Main Terraform configuration
│   ├── aap.tf                   # AAP Action configuration
│   ├── variables.tf             # Variable definitions
│   ├── outputs.tf               # Output definitions
│   ├── providers.tf             # Provider configuration
│   ├── terraform.tfvars.example # Example variables
│   └── modules/
│       ├── compute/             # VM provisioning module
│       └── network/             # Network configuration module
├── playbooks/
│   └── install-streamlit.yml    # Demo application installation
└── vault/
    └── configure-vm-policy.hcl  # Vault policy for VMs
```

## Customization

### Different Cloud Provider

The Terraform modules can be adapted for AWS or Azure:
- Replace `modules/compute/` with appropriate cloud resources
- Update firewall/security group configurations
- Modify the AAP inventory to use the correct hostname/IP

### Different Demo Application

Replace the Streamlit playbook with your own:
1. Create a new playbook in `playbooks/`
2. Update the AAP job template
3. Modify the `extra_vars` in the Action if needed

## Troubleshooting

### AAP Job Fails to Connect

1. **Check VM is reachable:**
   ```bash
   gcloud compute ssh --zone=us-central1-a your-vm-name
   ```

2. **Verify Vault CA key is on VM:**
   The VM startup script should fetch and install the Vault CA public key.

3. **Check AAP credential configuration:**
   Ensure the Machine credential is linked to the Vault credential.

### Terraform Action Doesn't Trigger

1. **Verify Terraform version:**
   ```bash
   terraform version  # Must be 1.14+
   ```

2. **Check action configuration:**
   Ensure the `action_trigger` is correctly configured in the lifecycle block.

### Vault Certificate Issues

1. **Check certificate validity:**
   ```bash
   vault write ssh-client-signer/sign/awx-role public_key=@/path/to/key.pub
   ```

2. **Verify AppRole credentials:**
   ```bash
   vault login -method=approle role_id=$ROLE_ID secret_id=$SECRET_ID
   ```

## Security Notes

- The AAP token in `terraform.tfvars` should be stored securely (consider using Vault or environment variables)
- VM startup scripts should use HTTPS to fetch the Vault CA key
- Consider using Vault's Kubernetes auth method if AAP runs in Kubernetes
