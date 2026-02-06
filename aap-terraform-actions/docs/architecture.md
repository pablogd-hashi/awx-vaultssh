# Architecture: Vault SSH CA + AAP + Terraform Actions

This document explains how the entire credential flow works, from VM creation to SSH authentication.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INFRASTRUCTURE FLOW                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  1. PACKER (Build Time)           2. TERRAFORM (Deploy Time)                │
│  ┌─────────────────────┐          ┌──────────────────────────────┐          │
│  │ Build Golden AMI    │          │ Create VMs from Golden AMI   │          │
│  │ - Install packages  │          │ - VPC, Subnet, Security Group│          │
│  │ - Pre-install apps  │          │ - EC2 instances              │          │
│  │ - Bake Vault CA key │          │ - Register hosts in AAP      │          │
│  └─────────────────────┘          └──────────────┬───────────────┘          │
│                                                  │                          │
│                                                  ▼                          │
│                                   3. TERRAFORM ACTION                       │
│                                   ┌──────────────────────────────┐          │
│                                   │ Trigger AAP Job Template     │          │
│                                   │ (after VM create/update)     │          │
│                                   └──────────────┬───────────────┘          │
│                                                  │                          │
│                                                  ▼                          │
│                                   4. AAP JOB EXECUTION                      │
│                                   ┌──────────────────────────────┐          │
│                                   │ Run playbook on new VMs      │          │
│                                   │ - Deploy Streamlit app       │          │
│                                   │ - Configure services         │          │
│                                   └──────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## How SSH Authentication Works

### The Problem with Traditional SSH

Traditional SSH authentication uses static keys:
- Keys must be distributed to all servers
- Key rotation is manual and error-prone
- Revocation requires touching every server
- No audit trail of who accessed what

### The Solution: Vault SSH CA

Vault acts as a Certificate Authority (CA) for SSH:
- Vault holds the CA private key (never exposed)
- VMs trust the CA public key (baked into golden image)
- Users/services get short-lived certificates signed by Vault
- Certificates expire automatically (default: 30 minutes)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        SSH CERTIFICATE FLOW                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   ┌─────────┐         ┌─────────┐         ┌─────────┐                       │
│   │   AAP   │         │  VAULT  │         │   VM    │                       │
│   └────┬────┘         └────┬────┘         └────┬────┘                       │
│        │                   │                   │                            │
│        │  1. Authenticate  │                   │                            │
│        │   (AppRole)       │                   │                            │
│        │──────────────────>│                   │                            │
│        │                   │                   │                            │
│        │  2. Vault Token   │                   │                            │
│        │<──────────────────│                   │                            │
│        │                   │                   │                            │
│        │  3. Sign my       │                   │                            │
│        │   public key      │                   │                            │
│        │──────────────────>│                   │                            │
│        │                   │                   │                            │
│        │  4. Signed cert   │                   │                            │
│        │   (30min TTL)     │                   │                            │
│        │<──────────────────│                   │                            │
│        │                   │                   │                            │
│        │  5. SSH with certificate             │                            │
│        │──────────────────────────────────────>│                            │
│        │                   │                   │                            │
│        │                   │    6. VM validates│                            │
│        │                   │    cert against   │                            │
│        │                   │    trusted CA key │                            │
│        │                   │    (baked in AMI) │                            │
│        │                   │                   │                            │
│        │  7. Session established              │                            │
│        │<──────────────────────────────────────│                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Packer Golden Image

**Purpose:** Bake the Vault CA public key into the AMI so VMs trust certificates signed by Vault.

**What it does:**
```
/etc/ssh/trusted-user-ca-keys.pem  <-- Vault CA public key
/etc/ssh/sshd_config               <-- TrustedUserCAKeys directive
/opt/streamlit-demo/venv/          <-- Pre-installed Python packages
```

**Why this matters:**
- VMs immediately trust Vault-signed certificates on boot
- No runtime configuration needed for SSH trust
- Pre-installed packages = faster Day-2 operations

**Key file:** `packer/vm-golden-image/main.pkr.hcl`

### 2. Vault SSH CA Module

**Purpose:** Configure Vault as an SSH Certificate Authority.

**What it creates:**

| Resource | Purpose |
|----------|---------|
| `vault_mount.ssh` | SSH secrets engine at `/ssh` |
| `vault_ssh_secret_backend_ca.ca` | Generate CA key pair |
| `vault_ssh_secret_backend_role.aap` | Signing role with TTL, allowed users |
| `vault_policy.aap_ssh` | Least-privilege policy for AAP |
| `vault_approle_auth_backend_role.aap` | AppRole for AAP authentication |

**Vault Policy (least privilege):**
```hcl
# Sign SSH public keys
path "ssh/sign/aap-ssh" {
  capabilities = ["create", "update"]
}

# Read CA public key
path "ssh/config/ca" {
  capabilities = ["read"]
}
```

**Key file:** `terraform/modules/vault-ssh-ca/main.tf`

### 3. Terraform Actions

**Purpose:** Automatically trigger AAP when infrastructure changes.

**How it works:**
```hcl
# Define the action
action "aap_job_launch" "configure_vms" {
  config {
    job_template_id                     = data.aap_job_template.configure.id
    wait_for_completion                 = true
    wait_for_completion_timeout_seconds = 600
  }
}

# Trigger on VM changes
resource "terraform_data" "aap_trigger" {
  input = join(",", [for k, v in module.vm.inventory : v.ansible_host])

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vms]
    }
  }
}
```

**Flow:**
1. Terraform creates/updates VMs
2. `terraform_data.aap_trigger` detects change in VM IPs
3. `action_trigger` fires `aap_job_launch` action
4. AAP job template runs against new VMs

**Key file:** `terraform/infra/main.tf`

### 4. AAP Credential Flow

**How AAP gets SSH access:**

1. **AAP has Vault AppRole credentials** (configured manually in AAP)
   - Role ID: Identifies the application
   - Secret ID: Proves identity (rotatable)

2. **Before SSH connection, AAP calls Vault:**
   ```bash
   # Authenticate to Vault
   vault write auth/approle/login \
     role_id=$ROLE_ID \
     secret_id=$SECRET_ID

   # Sign SSH public key
   vault write ssh/sign/aap-ssh \
     public_key=@~/.ssh/id_ed25519.pub \
     valid_principals=ansible
   ```

3. **AAP receives signed certificate:**
   ```
   -----BEGIN CERTIFICATE-----
   ...certificate valid for 30 minutes...
   -----END CERTIFICATE-----
   ```

4. **AAP connects to VM:**
   ```bash
   ssh -i ~/.ssh/id_ed25519 \
       -o CertificateFile=~/.ssh/id_ed25519-cert.pub \
       ansible@<vm-ip>
   ```

5. **VM validates certificate:**
   - Checks signature against `/etc/ssh/trusted-user-ca-keys.pem`
   - Verifies `valid_principals` includes the username
   - Checks certificate hasn't expired
   - Grants access if all checks pass

## Security Properties

| Property | How It's Achieved |
|----------|-------------------|
| **No static keys on VMs** | VMs only have CA public key, not AAP's private key |
| **Short-lived access** | Certificates expire in 30 minutes by default |
| **Automatic rotation** | New certificate signed before each connection |
| **Audit trail** | Vault logs every certificate signing request |
| **Least privilege** | AppRole policy only allows signing, not CA admin |
| **Revocation** | Rotate CA key in Vault, update golden image |

## Data Flow Summary

```
┌──────────────────────────────────────────────────────────────────────────┐
│ STEP 1: BUILD TIME (Packer)                                              │
├──────────────────────────────────────────────────────────────────────────┤
│ Vault ──(CA public key)──> Packer ──(bake into AMI)──> AWS AMI           │
└──────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STEP 2: DEPLOY TIME (Terraform)                                          │
├──────────────────────────────────────────────────────────────────────────┤
│ Terraform ──(create VMs)──> AWS EC2                                      │
│ Terraform ──(register hosts)──> AAP Inventory                            │
│ Terraform ──(trigger action)──> AAP Job Template                         │
└──────────────────────────────────────────────────────────────────────────┘
                                        │
                                        ▼
┌──────────────────────────────────────────────────────────────────────────┐
│ STEP 3: CONFIGURATION TIME (AAP)                                         │
├──────────────────────────────────────────────────────────────────────────┤
│ AAP ──(AppRole auth)──> Vault                                            │
│ Vault ──(Vault token)──> AAP                                             │
│ AAP ──(sign public key)──> Vault                                         │
│ Vault ──(signed certificate)──> AAP                                      │
│ AAP ──(SSH with cert)──> VM                                              │
│ VM ──(validate cert vs CA key)──> Access Granted                         │
│ AAP ──(run playbook)──> VM configured                                    │
└──────────────────────────────────────────────────────────────────────────┘
```

## Files Reference

| File | Purpose |
|------|---------|
| `packer/vm-golden-image/main.pkr.hcl` | Golden AMI with CA key |
| `terraform/modules/vault-ssh-ca/main.tf` | Vault SSH CA configuration |
| `terraform/modules/vm/main.tf` | EC2 instances from golden AMI |
| `terraform/infra/main.tf` | Main infra + Terraform Action |
| `playbooks/install-streamlit.yml` | AAP playbook for Day-2 config |
| `docs/aap-prerequisites.md` | AAP credential type setup |

## Troubleshooting

### Certificate validation fails

```bash
# On VM, check CA key is present
cat /etc/ssh/trusted-user-ca-keys.pem

# Check sshd config
grep TrustedUserCAKeys /etc/ssh/sshd_config

# Test certificate manually
ssh-keygen -L -f /path/to/cert.pub
```

### AAP can't authenticate to Vault

```bash
# Test AppRole login
vault write auth/approle/login \
  role_id="<role_id>" \
  secret_id="<secret_id>"

# Check role exists
vault read auth/approle/role/aap-vault-ssh-demo
```

### Terraform Action doesn't trigger

```bash
# Check Terraform version (need 1.14+)
terraform version

# Check AAP provider version (need 1.4+)
terraform providers

# Manual trigger
terraform apply -replace="terraform_data.aap_trigger"
```

## Related Documentation

- [AAP Prerequisites](aap-prerequisites.md) - Credential type setup
- [Vault SSH CA Docs](https://developer.hashicorp.com/vault/docs/secrets/ssh/signed-ssh-certificates)
- [Terraform Actions](https://developer.hashicorp.com/terraform/language/resources/provisioners/syntax#action-blocks)
- [AAP Terraform Provider](https://registry.terraform.io/providers/ansible/aap/latest/docs)
