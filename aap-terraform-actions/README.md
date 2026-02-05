# AAP Terraform Actions - Vault SSH CA

Comprehensive deployment solution using **Terraform Actions**, **HashiCorp Vault SSH CA**, and **Red Hat Ansible Automation Platform** to provision and configure VMs with certificate-based SSH authentication.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SINGLE TERRAFORM APPLY                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Phase 1: Vault Provisioning                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • SSH secrets engine                                                │   │
│   │  • SSH CA signing key                                                │   │
│   │  • SSH role for certificate issuance                                │   │
│   │  • AppRole auth method + policy                                     │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│   Phase 2: AWS Infrastructure                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • VPC, subnet, internet gateway                                    │   │
│   │  • Security groups (SSH + app ports)                                │   │
│   │  • EC2 instances (from golden AMI)                                  │   │
│   │  • AAP inventory hosts                                              │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│   Phase 3: AAP Trigger (Terraform Action)                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • Passes AppRole credentials via extra_vars                        │   │
│   │  • Playbook authenticates to Vault                                  │   │
│   │  • Gets SSH credentials (Option A or B)                             │   │
│   │  • Configures target VMs                                            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Two Credential Options

### Option A: Vault Secrets Lookup (Ephemeral Keys)

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    OPTION A: EPHEMERAL KEYS                                 │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AAP Controller                         Vault                               │
│  ┌───────────────┐                     ┌───────────────┐                   │
│  │               │ 1. AppRole login    │               │                   │
│  │   Ansible     │────────────────────>│   /auth/      │                   │
│  │   Playbook    │<────────────────────│   approle     │                   │
│  │               │    client_token     │               │                   │
│  │               │                     │               │                   │
│  │               │ 2. POST /ssh/issue  │               │                   │
│  │               │────────────────────>│   /ssh/issue  │                   │
│  │               │<────────────────────│   /:role      │                   │
│  │               │  private_key +      │               │                   │
│  │               │  signed_cert        └───────────────┘                   │
│  │               │                                                          │
│  │               │ 3. SSH with ephemeral creds                             │
│  │               │─────────────────────────────────────>  Target VM        │
│  │               │                                                          │
│  │               │ 4. Shred credentials                                    │
│  └───────────────┘                                                          │
│                                                                             │
│  ✓ No static keys stored anywhere                                          │
│  ✓ Keys generated fresh for each connection                                │
│  ✓ Automatic credential rotation                                           │
│  ✓ Keys shredded after use                                                 │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Option B: Vault Signed SSH (Static Key in AAP)

```
┌────────────────────────────────────────────────────────────────────────────┐
│                    OPTION B: SIGNED SSH                                     │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  AAP Controller                         Vault                               │
│  ┌───────────────┐                     ┌───────────────┐                   │
│  │               │ 1. AppRole login    │               │                   │
│  │   Static      │────────────────────>│   /auth/      │                   │
│  │   Private Key │<────────────────────│   approle     │                   │
│  │   (in AAP)    │    client_token     │               │                   │
│  │               │                     │               │                   │
│  │               │ 2. POST /ssh/sign   │               │                   │
│  │   Public Key  │────────────────────>│   /ssh/sign   │                   │
│  │               │<────────────────────│   /:role      │                   │
│  │               │    signed_cert      │               │                   │
│  │               │    (30 min TTL)     └───────────────┘                   │
│  │               │                                                          │
│  │               │ 3. SSH with static key + fresh cert                     │
│  │               │─────────────────────────────────────>  Target VM        │
│  │               │                                                          │
│  └───────────────┘                                                          │
│                                                                             │
│  ✓ Works with existing AAP Machine Credentials                             │
│  ✓ Private key securely stored in AAP                                      │
│  ✓ Certificates are short-lived (default 30 min)                           │
│  ✓ Compatible with enterprise key management                               │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

## Project Structure

```
aap-terraform-actions/
├── README.md                           # This file
├── Taskfile.yml                        # Task runner commands
│
├── packer/
│   ├── vm-golden-image/               # Golden VM image with Vault SSH CA
│   │   ├── main.pkr.hcl               # Packer configuration (AWS/RHEL9)
│   │   └── variables.pkr.hcl          # Packer variables
│   │
│   └── aap-controller/                # AAP Controller image
│       ├── main.pkr.hcl               # Packer configuration
│       ├── variables.pkr.hcl          # Packer variables
│       ├── bootstrap.sh               # First-boot installation script
│       └── inventory.pkrtpl.hcl       # AAP inventory template
│
├── terraform/
│   ├── aws/                           # AWS Infrastructure (primary)
│   │   ├── providers.tf               # Provider configuration
│   │   ├── variables.tf               # Variable definitions
│   │   ├── vault.tf                   # Vault SSH CA provisioning
│   │   ├── network.tf                 # VPC, subnets, security groups
│   │   ├── ec2.tf                     # EC2 instances
│   │   ├── aap.tf                     # AAP hosts + job trigger action
│   │   ├── outputs.tf                 # Output values
│   │   └── terraform.tfvars.example   # Example configuration
│   │
│   └── (gcp/)                         # GCP Infrastructure (legacy)
│       └── ...
│
└── playbooks/
    ├── vault-ssh-main.yml             # Router - selects Option A or B
    ├── option-a-ephemeral-keys.yml    # Option A: Ephemeral keys
    ├── option-b-signed-ssh.yml        # Option B: Signed SSH
    ├── vault-ssh-configure.yml        # Legacy playbook (Option A)
    ├── issue_ssh_creds.yml            # Legacy helper
    └── tasks/
        └── issue-ssh-credentials.yml  # Issue creds for single host
```

## Prerequisites

- **Terraform** >= 1.14.0 (required for Actions)
- **Packer** >= 1.9.0
- **AWS CLI** configured with credentials
- **Vault CLI** (optional, for testing)
- **Task** (go-task/task) for running commands

## Quick Start

### 1. Build Golden VM Image

```bash
# Check prerequisites
task check

# Build the golden image (auto-fetches Vault CA key)
task packer:vm:build:auto
```

### 2. Configure Terraform

```bash
# Copy example tfvars
cp terraform/aws/terraform.tfvars.example terraform/aws/terraform.tfvars

# Edit with your values
vim terraform/aws/terraform.tfvars
```

Required variables:
```hcl
# Vault
vault_addr      = "https://vault.example.com:8200"
vault_token     = "hvs.xxxxx"
vault_namespace = "admin"  # For HCP Vault

# AAP
aap_host     = "https://aap.example.com"
aap_username = "admin"
aap_password = "your-password"

# Credential option: "A" or "B"
credential_option = "A"
```

### 3. Deploy Infrastructure

```bash
# Option A: Ephemeral keys (recommended)
task demo:option-a

# Option B: Signed SSH
task demo:option-b
```

### 4. Verify Deployment

```bash
# Show outputs
task tf:output

# SSH to a VM (using Vault-signed certificate)
ssh -i /path/to/key -i /path/to/cert.pub ansible@<vm-ip>
```

## Task Commands Reference

### Packer Commands

| Command | Description |
|---------|-------------|
| `task packer:vm:init` | Initialize Packer for VM image |
| `task packer:vm:build:auto` | Build VM image (auto-fetch CA key) |
| `task packer:aap:init` | Initialize Packer for AAP image |
| `task packer:aap:build` | Build AAP controller image |
| `task packer:build:all` | Build all images |

### Terraform Commands

| Command | Description |
|---------|-------------|
| `task tf:init` | Initialize Terraform |
| `task tf:plan` | Plan infrastructure |
| `task tf:apply` | Apply infrastructure |
| `task tf:apply:option-a` | Apply with Option A |
| `task tf:apply:option-b` | Apply with Option B |
| `task tf:destroy` | Destroy infrastructure |
| `task tf:invoke` | Manually invoke AAP action |

### Vault Commands

| Command | Description |
|---------|-------------|
| `task vault:status` | Check Vault SSH CA status |
| `task vault:ca-key` | Get CA public key |
| `task vault:test:issue` | Test /ssh/issue endpoint |
| `task vault:test:sign` | Test /ssh/sign endpoint |

### Demo Flows

| Command | Description |
|---------|-------------|
| `task demo:option-a` | Full demo with ephemeral keys |
| `task demo:option-b` | Full demo with signed SSH |
| `task demo:full` | Build images + deploy |

## Security Model

### Traditional SSH vs Vault SSH CA

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      TRADITIONAL SSH                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  x Static private keys scattered across systems                        │
│  x Public keys in authorized_keys (manual management)                  │
│  x Keys never expire (unless manually rotated)                         │
│  x Key revocation is painful                                           │
│  x Audit trail: "someone with this key logged in"                      │
│                                                                          │
│  AAP Credential Store                    Target VMs                     │
│  ┌─────────────────────┐                ┌─────────────────────┐        │
│  │  private_key.pem    │────SSH────────>│  authorized_keys    │        │
│  │  (static, forever)  │                │  (static, forever)  │        │
│  └─────────────────────┘                └─────────────────────┘        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                       VAULT SSH CA                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  v Short-lived certificates (30 min default)                           │
│  v VMs trust the CA, not individual keys                               │
│  v Automatic expiration - no manual revocation needed                  │
│  v Certificates can encode identity (principal)                        │
│  v Full audit trail in Vault                                           │
│                                                                          │
│  Vault SSH CA                            Target VMs                     │
│  ┌─────────────────────┐                ┌─────────────────────┐        │
│  │  Sign certificates  │────CERT───────>│  TrustedUserCAKeys  │        │
│  │  TTL: 30 minutes    │                │  (trusts CA only)   │        │
│  └─────────────────────┘                └─────────────────────┘        │
│          ▲                                                              │
│          │                                                              │
│  ┌───────┴───────┐                                                      │
│  │ AppRole Auth  │ ← AAP authenticates here                            │
│  │ Policy-based  │                                                      │
│  └───────────────┘                                                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## AAP Configuration

### No Manual Credential Setup Required!

This solution passes all Vault credentials via `extra_vars`, so you don't need to configure AAP credentials manually:

```hcl
# terraform/aws/aap.tf
extra_vars = jsonencode({
  vault_approle_role_id   = local.vault_approle_role_id
  vault_approle_secret_id = local.vault_approle_secret_id
  # ... other vars
})
```

### Job Template Setup

1. **Create Project** pointing to this repo
2. **Create Inventory** (can be empty - hosts added dynamically)
3. **Create Job Template**:
   - Playbook: `playbooks/vault-ssh-main.yml`
   - Extra Variables: Leave empty (provided by Terraform)

## Terraform Actions

### What Are Actions?

Terraform Actions (v1.14+) are declarative triggers for non-CRUD operations:

```hcl
action "aap_job_launch" "configure_vm" {
  config {
    job_template_id     = data.aap_job_template.configure_vm.id
    wait_for_completion = true
    extra_vars          = jsonencode({ ... })
  }
}

resource "aap_host" "vm" {
  # ...
  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vm]
    }
  }
}
```

### Why Actions Instead of Resources?

| Aspect | Resource (old) | Action (new) |
|--------|---------------|--------------|
| State | Tracked by Terraform | Not tracked |
| Destroy | Tries to "destroy" the job | No-op |
| Re-run | May unexpectedly re-trigger | Explicit triggers |
| Manual invoke | Not supported | `terraform apply -invoke` |

### Manual Invocation

```bash
# Re-run the AAP job without changing infrastructure
task tf:invoke
# or
terraform apply -invoke action.aap_job_launch.configure_vm
```

## Troubleshooting

### Packer Build Fails

```bash
# Check Vault connectivity
task vault:status

# Get CA key manually
vault read -field=public_key ssh/config/ca
```

### Terraform Apply Fails

```bash
# Validate configuration
task tf:validate

# Check provider versions
terraform version
```

### AAP Job Fails

1. Check AAP job output in the web UI
2. Verify Vault credentials:
   ```bash
   task vault:test:issue  # Test Option A
   task vault:test:sign   # Test Option B
   ```
3. Check target VM is reachable (security groups)

### SSH Connection Fails

1. Verify golden image has Vault CA configured:
   ```bash
   # On target VM
   cat /etc/ssh/trusted-user-ca-keys.pem
   grep TrustedUserCAKeys /etc/ssh/sshd_config
   ```
2. Check certificate validity:
   ```bash
   ssh-keygen -L -f /path/to/cert.pub
   ```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `VAULT_ADDR` | Vault server URL |
| `VAULT_TOKEN` | Vault authentication token |
| `VAULT_NAMESPACE` | Vault namespace (for HCP/Enterprise) |
| `AWS_REGION` | AWS region (default: us-east-1) |
| `AAP_SETUP_BUNDLE` | Path to AAP setup bundle (for packer:aap:build) |

## Related Projects

- [terraform-actions-ansible-job-vault-ssh-vm-config](https://github.com/pablogd-hashi/terraform-actions-ansible-job-vault-ssh-vm-config) - Original reference implementation
- [promptOPS-tf-aap](../../../ai/promptOPS/promptOPS-tf-aap/) - PromptOPS variant with multi-VM support
