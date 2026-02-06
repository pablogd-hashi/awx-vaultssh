# AAP Terraform Actions - Vault SSH CA

Comprehensive deployment solution using **Terraform Actions**, **HashiCorp Vault SSH CA**, and **Red Hat Ansible Automation Platform** to provision and configure VMs with certificate-based SSH authentication.

> **Note:** This repository assumes you have an existing AAP (Ansible Automation Platform) controller. AAP is a licensed Red Hat product and is not deployed by this repository. See [AAP Prerequisites](docs/aap-prerequisites.md) for required configuration.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SINGLE TERRAFORM APPLY                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Prerequisites (External)                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • Existing AAP controller (licensed, not provisioned here)         │   │
│   │  • HashiCorp Vault with network access                               │   │
│   │  • AWS credentials configured                                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│   Phase 1: Vault SSH CA Configuration                                       │
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
│   │  • Security groups (SSH access)                                      │   │
│   │  • EC2 instances (from golden AMI with Vault CA)                    │   │
│   │  • AAP inventory + hosts                                             │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                    │                                        │
│                                    ▼                                        │
│   Phase 3: AAP Trigger (Terraform Action)                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • Triggers AAP job on VM create/update                             │   │
│   │  • Playbook connects using Vault SSH credentials                    │   │
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
├── docs/
│   └── aap-prerequisites.md           # AAP setup requirements
│
├── packer/
│   └── vm-golden-image/               # Golden VM image with Vault SSH CA
│       ├── main.pkr.hcl               # Packer configuration (AWS/RHEL9)
│       └── variables.pkr.hcl          # Packer variables
│
├── terraform/
│   ├── infra/                         # Main infrastructure deployment
│   │   ├── main.tf                    # Resources + Terraform Action
│   │   ├── variables.tf               # Variable definitions
│   │   ├── outputs.tf                 # Output values
│   │   ├── providers.tf               # Provider configuration
│   │   └── terraform.tfvars.example   # Example configuration
│   │
│   └── modules/
│       ├── vault-ssh-ca/              # Vault SSH CA configuration
│       │   ├── main.tf                # SSH engine, role, AppRole
│       │   ├── variables.tf           # Module variables
│       │   └── outputs.tf             # AppRole credentials output
│       │
│       └── vm/                        # AWS EC2 instances
│           ├── main.tf                # Instance + security group
│           ├── variables.tf           # Module variables
│           └── outputs.tf             # Inventory output
│
└── playbooks/                         # Ansible playbooks (reference)
    └── configure.yml                  # VM configuration playbook
```

## Prerequisites

### Tools
- **Terraform** >= 1.14.0 (required for Actions)
- **AAP Terraform Provider** >= 1.4.0 (required for `aap_job_launch` action)
- **Packer** >= 1.9.0
- **AWS CLI** configured with credentials
- **Vault CLI** (optional, for testing)
- **Task** (go-task/task) for running commands

### External Services (Not Provisioned by This Repo)
- **Ansible Automation Platform (AAP)** - Existing controller with API access
  - See [AAP Prerequisites](docs/aap-prerequisites.md) for required credential types
- **HashiCorp Vault** - With network access from AAP controller
- **AWS VPC** - Existing VPC and subnet for VM deployment

## Quick Start

### 1. Configure AAP Prerequisites

Before deploying, ensure your AAP controller has the required credential types configured.
See [docs/aap-prerequisites.md](docs/aap-prerequisites.md) for detailed setup instructions.

### 2. Build Golden VM Image

```bash
# Check prerequisites
task check

# Build the golden image (auto-fetches Vault CA key)
task packer:build:auto
```

### 3. Configure Terraform

```bash
# Copy example tfvars
cp terraform/infra/terraform.tfvars.example terraform/infra/terraform.tfvars

# Edit with your values
vim terraform/infra/terraform.tfvars
```

Required variables:
```hcl
# AAP (existing controller)
aap_host            = "https://aap.example.com"
aap_username        = "admin"
aap_password        = "your-password"
aap_job_template_id = 42  # Get ID from AAP UI

# Vault
vault_addr      = "https://vault.example.com:8200"
vault_token     = ""  # Use VAULT_TOKEN env var
vault_namespace = "admin"  # For HCP Vault; leave empty for OSS
```

### 4. Deploy Infrastructure

```bash
# Option A: Vault Signed SSH (static key)
task demo:option-a

# Option B: Vault Secrets Lookup (ephemeral keys)
task demo:option-b
```

### 5. Verify Deployment

```bash
# Show outputs
task infra:output

# SSH to a VM (using Vault-signed certificate)
ssh -i /path/to/key -i /path/to/cert.pub ansible@<vm-ip>
```

## Task Commands Reference

### Packer Commands

| Command | Description |
|---------|-------------|
| `task packer:init` | Initialize Packer for VM image |
| `task packer:validate` | Validate Packer configuration |
| `task packer:build` | Build VM golden image |
| `task packer:build:auto` | Build VM image (auto-fetch CA key from Vault) |

### Infrastructure Commands

| Command | Description |
|---------|-------------|
| `task infra:init` | Initialize Terraform |
| `task infra:init:upgrade` | Upgrade Terraform providers |
| `task infra:validate` | Validate Terraform configuration |
| `task infra:plan` | Plan infrastructure |
| `task infra:plan:option-a` | Plan with Option A (Signed SSH) |
| `task infra:plan:option-b` | Plan with Option B (Ephemeral) |
| `task infra:deploy` | Deploy infrastructure |
| `task infra:deploy:auto` | Deploy infrastructure (auto-approve) |
| `task infra:deploy:option-a` | Deploy with Option A |
| `task infra:deploy:option-b` | Deploy with Option B |
| `task infra:destroy` | Destroy infrastructure |
| `task infra:output` | Show infrastructure outputs |

### Vault Commands

| Command | Description |
|---------|-------------|
| `task vault:status` | Check Vault SSH CA status |
| `task vault:ca-key` | Get CA public key |
| `task vault:test:sign` | Test /ssh/sign endpoint (Option A) |
| `task vault:test:issue` | Test /ssh/issue endpoint (Option B) |

### Demo Flows

| Command | Description |
|---------|-------------|
| `task demo:option-a` | Full demo with Option A (Signed SSH) |
| `task demo:option-b` | Full demo with Option B (Ephemeral) |
| `task demo:full` | Build golden image + deploy infrastructure |

### Cleanup Commands

| Command | Description |
|---------|-------------|
| `task clean:infra` | Clean Terraform state files |
| `task clean:packer` | Clean Packer cache |
| `task clean:all` | Clean everything |

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

### Required Setup

This repository requires an existing AAP controller with specific credential types configured.
See [docs/aap-prerequisites.md](docs/aap-prerequisites.md) for complete setup instructions.

**Summary of required credential types:**

| Option | Credential Type | Description |
|--------|-----------------|-------------|
| A | `HashiCorp Vault Signed SSH` | Static key signed by Vault CA |
| B | `HashiCorp Vault Secret Lookup` | Source credential for ephemeral keys |
| B | `Machine` | Linked to Vault lookup for dynamic SSH key |

### What Terraform Creates in AAP

Terraform will automatically create these resources in your AAP:

- **Inventory** with hosts for deployed VMs
- **Project** linked to your playbook repository
- **Credentials** (based on selected option)
- **Job Template** configured to use the credentials

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

## Related Documentation

- [AAP Prerequisites](docs/aap-prerequisites.md) - Required AAP credential types and setup
- [Vault SSH CA](https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates) - Vault SSH secrets engine documentation
- [Terraform Actions](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax#action-blocks) - Terraform 1.14+ Actions reference
