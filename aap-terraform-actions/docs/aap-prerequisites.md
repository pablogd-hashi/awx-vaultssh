# AAP Prerequisites

This document describes the credential types and configuration required in Ansible Automation Platform (AAP) before deploying the infrastructure.

## Required Credential Types

The infrastructure supports two credential options. Each requires specific credential types to be configured in AAP.

### Option A: HashiCorp Vault Signed SSH

Uses a static SSH key stored in AAP that gets signed by Vault's SSH CA before each connection.

**Required Credential Type:** `HashiCorp Vault Signed SSH`

This credential type should already be available in AAP 2.4+. If not present, create it manually:

1. Navigate to **Administration → Credential Types**
2. Click **Add**
3. Configure:

**Name:** `HashiCorp Vault Signed SSH`

**Input Configuration:**
```yaml
fields:
  - id: vault_addr
    type: string
    label: Vault Server URL
  - id: vault_namespace
    type: string
    label: Vault Namespace
    help_text: Leave empty for OSS Vault, use 'admin' for HCP Vault
  - id: role_id
    type: string
    label: AppRole Role ID
    secret: true
  - id: secret_id
    type: string
    label: AppRole Secret ID
    secret: true
  - id: ssh_key_data
    type: string
    label: SSH Private Key
    format: ssh_private_key
    secret: true
    multiline: true
  - id: public_key_data
    type: string
    label: SSH Public Key
    multiline: true
  - id: ssh_mount_point
    type: string
    label: SSH Secrets Engine Path
    help_text: Default is 'ssh'
  - id: role
    type: string
    label: SSH Role Name
required:
  - vault_addr
  - role_id
  - secret_id
  - ssh_key_data
  - public_key_data
  - ssh_mount_point
  - role
```

**Injector Configuration:**
```yaml
extra_vars:
  vault_addr: '{{ vault_addr }}'
  vault_namespace: '{{ vault_namespace }}'
  vault_ssh_mount: '{{ ssh_mount_point }}'
  vault_ssh_role: '{{ role }}'
env:
  VAULT_ADDR: '{{ vault_addr }}'
  VAULT_NAMESPACE: '{{ vault_namespace }}'
  ANSIBLE_HOST_KEY_CHECKING: 'False'
file:
  template.ssh_key_data: '{{ ssh_key_data }}'
  template.ssh_public_key: '{{ public_key_data }}'
```

### Option B: HashiCorp Vault Secret Lookup

Uses Vault to generate ephemeral SSH key pairs on-demand. No static keys are stored.

**Required Credential Type:** `HashiCorp Vault Secret Lookup`

This credential type should already be available in AAP 2.4+. If not present, create it manually:

1. Navigate to **Administration → Credential Types**
2. Click **Add**
3. Configure:

**Name:** `HashiCorp Vault Secret Lookup`

**Input Configuration:**
```yaml
fields:
  - id: vault_addr
    type: string
    label: Vault Server URL
  - id: vault_namespace
    type: string
    label: Vault Namespace
    help_text: Leave empty for OSS Vault
  - id: auth_path
    type: string
    label: AppRole Auth Path
    help_text: Default is 'approle'
  - id: role_id
    type: string
    label: AppRole Role ID
    secret: true
  - id: secret_id
    type: string
    label: AppRole Secret ID
    secret: true
required:
  - vault_addr
  - role_id
  - secret_id
```

**Injector Configuration:**
```yaml
env:
  VAULT_ADDR: '{{ vault_addr }}'
  VAULT_NAMESPACE: '{{ vault_namespace }}'
  VAULT_AUTH_PATH: '{{ auth_path }}'
  VAULT_ROLE_ID: '{{ role_id }}'
  VAULT_SECRET_ID: '{{ secret_id }}'
```

## Verification

To verify credential types are available:

1. Navigate to **Resources → Credentials**
2. Click **Add**
3. In the **Credential Type** dropdown, verify you can see:
   - `HashiCorp Vault Signed SSH` (for Option A)
   - `HashiCorp Vault Secret Lookup` (for Option B)
   - `Machine` (standard, always available)

## Organization

The Terraform configuration expects an organization to exist. By default, it uses `Default`.

To use a different organization:
1. Navigate to **Access → Organizations**
2. Create a new organization or note the name of an existing one
3. Set `aap_organization = "YourOrgName"` in `terraform.tfvars`

## Network Requirements

AAP controller must be able to reach:

1. **Vault Server** - For SSH certificate signing
   - Default port: 8200 (HTTPS)
   - Ensure firewall allows outbound connections

2. **Target VMs** - For SSH connections
   - Port 22 (SSH)
   - VMs must be in a network reachable from AAP

3. **Git Repository** - For project sync (if using external playbooks)
   - Port 443 (HTTPS) for GitHub/GitLab

## Vault Requirements

Before deploying infrastructure, ensure Vault has:

1. **SSH Secrets Engine** mounted (Terraform will create if not exists)
2. **AppRole Auth** enabled (Terraform will create if not exists)
3. **Network access** from AAP controller

The Terraform Vault SSH CA module will automatically configure:
- SSH CA key pair
- SSH signing role
- AppRole role and policy
- Secret ID for AAP

## Troubleshooting

### "Credential type not found"

If Terraform fails with credential type errors:
1. Verify the credential type exists in AAP (see above)
2. Check the exact name matches (case-sensitive)
3. Ensure you're using AAP 2.4+ which includes Vault credential types

### "Organization not found"

1. Verify the organization exists in AAP
2. Check `aap_organization` variable matches exactly
3. Ensure the API user has access to the organization

### "Connection refused" to Vault

1. Verify `vault_address` is correct and reachable from AAP
2. Check firewall rules allow outbound HTTPS (8200)
3. For HCP Vault, ensure `vault_namespace` is set to `admin`

### SSH connection failures

1. Verify target VMs have the Vault CA public key in `/etc/ssh/trusted-user-ca-keys.pem`
2. Check the `ansible` user exists on target VMs
3. Verify security group allows SSH from AAP controller
