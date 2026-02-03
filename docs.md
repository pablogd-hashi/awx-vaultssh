# Architecture Documentation

This document describes the architecture and design of the Vault SSH CA integration with Ansible Automation Platform.

## Table of Contents

- [Problem Statement](#problem-statement)
- [Solution Overview](#solution-overview)
- [Component Architecture](#component-architecture)
- [Credential Flow](#credential-flow)
- [Vault SSH CA Configuration](#vault-ssh-ca-configuration)
- [AAP Credential Types](#aap-credential-types)
- [Security Considerations](#security-considerations)

---

## Problem Statement

Managing SSH access at scale presents several challenges:

1. **Key Distribution** - Distributing public keys to hundreds or thousands of servers is operationally complex
2. **Key Rotation** - Rotating compromised or expired keys requires touching every server
3. **Audit Trail** - Tracking who has access to what is difficult with distributed authorized_keys files
4. **Credential Sprawl** - Long-lived static keys accumulate and become security risks
5. **Onboarding/Offboarding** - Adding or removing user access requires coordinated changes across all systems

## Solution Overview

HashiCorp Vault's SSH Certificate Authority solves these problems by:

- **Centralizing trust** - Servers trust Vault's CA public key, not individual user keys
- **Short-lived certificates** - Certificates expire automatically (configurable TTL)
- **Dynamic issuance** - Credentials are generated on-demand, not stored
- **Audit logging** - Every certificate issuance is logged in Vault
- **Role-based access** - Vault policies control who can request certificates

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CERTIFICATE FLOW                                   │
└─────────────────────────────────────────────────────────────────────────────┘

   ┌──────────┐         ┌──────────┐         ┌──────────┐         ┌──────────┐
   │   AAP    │         │  Vault   │         │   SSH    │         │  Target  │
   │Controller│         │  Server  │         │   CA     │         │   VM     │
   └────┬─────┘         └────┬─────┘         └────┬─────┘         └────┬─────┘
        │                    │                    │                    │
        │ 1. Authenticate    │                    │                    │
        │    (AppRole)       │                    │                    │
        │───────────────────>│                    │                    │
        │                    │                    │                    │
        │ 2. Request signed  │                    │                    │
        │    certificate     │                    │                    │
        │───────────────────>│                    │                    │
        │                    │                    │                    │
        │                    │ 3. Sign public key │                    │
        │                    │    with CA         │                    │
        │                    │───────────────────>│                    │
        │                    │                    │                    │
        │ 4. Return signed   │<───────────────────│                    │
        │    certificate     │                    │                    │
        │<───────────────────│                    │                    │
        │                    │                    │                    │
        │ 5. SSH connect with certificate         │                    │
        │─────────────────────────────────────────────────────────────>│
        │                    │                    │                    │
        │                    │                    │    6. Validate     │
        │                    │                    │    certificate     │
        │                    │                    │<───────────────────│
        │                    │                    │                    │
        │ 7. Connection established               │                    │
        │<─────────────────────────────────────────────────────────────│
        │                    │                    │                    │
```

---

## Component Architecture

### Core Components

| Component | Role | Description |
|-----------|------|-------------|
| **Vault Server** | Certificate Authority | Signs SSH public keys and manages credentials |
| **AAP/AWX Controller** | Automation Platform | Orchestrates playbook execution with dynamic credentials |
| **Target VMs** | Managed Nodes | Trust Vault's CA and accept signed certificates |
| **Terraform** | Infrastructure Provisioning | Creates VMs and triggers AAP via Actions |

### Vault Components

```
Vault Server
├── Auth Methods
│   ├── AppRole (for AAP authentication)
│   └── Kubernetes (for pods, optional)
│
├── Secrets Engines
│   └── SSH (path: ssh-client-signer)
│       └── Roles
│           └── aap-role (certificate signing role)
│
└── Policies
    └── lab-policy (permissions for SSH signing)
```

### Target VM Configuration

Target VMs must be configured to trust Vault's CA. This requires adding a single line to the SSH daemon configuration:

```
# /etc/ssh/sshd_config
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
```

The `trusted-user-ca-keys.pem` file contains Vault's SSH CA public key.

---

## Credential Flow

### Step-by-Step Process

1. **Job Initiation** - AAP job template is triggered (manually or via Terraform Actions)

2. **Credential Resolution** - AAP detects the Machine credential uses external secrets

3. **Vault Authentication** - AAP authenticates to Vault using AppRole (role_id + secret_id)

4. **Certificate Request** - AAP sends its public key to Vault for signing:
   ```
   POST /v1/ssh-client-signer/sign/aap-role
   {
     "public_key": "<AAP's public key>",
     "valid_principals": "rhel,ubuntu"
   }
   ```

5. **Certificate Issuance** - Vault signs the key and returns a certificate with:
   - Configured TTL (default: 30 minutes)
   - Allowed principals
   - Extensions (permit-pty, etc.)

6. **SSH Connection** - AAP connects to target using:
   - Private key
   - Signed certificate (as proof of identity)

7. **Certificate Validation** - Target VM validates the certificate against the trusted CA key

8. **Playbook Execution** - Connection established, playbook runs

---

## Vault SSH CA Configuration

### Enable SSH Secrets Engine

```bash
vault secrets enable -path=ssh-client-signer ssh
```

### Generate CA Key Pair

```bash
vault write ssh-client-signer/config/ca generate_signing_key=true
```

### Create Signing Role

```bash
vault write ssh-client-signer/roles/aap-role - <<EOF
{
  "algorithm_signer": "rsa-sha2-256",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": {
    "permit-pty": ""
  },
  "key_type": "ca",
  "default_user": "rhel,ubuntu",
  "ttl": "30m0s"
}
EOF
```

### Role Parameters Explained

| Parameter | Value | Description |
|-----------|-------|-------------|
| `algorithm_signer` | `rsa-sha2-256` | SSH signature algorithm |
| `allow_user_certificates` | `true` | Enable user certificate signing |
| `allowed_users` | `*` | Which usernames can be in certificates |
| `allowed_extensions` | `permit-pty,...` | SSH extensions to allow |
| `key_type` | `ca` | Vault acts as CA (not OTP) |
| `default_user` | `rhel,ubuntu` | Default principals if not specified |
| `ttl` | `30m0s` | Certificate validity period |

### AppRole Configuration

```bash
# Enable AppRole auth
vault auth enable approle

# Create role for AAP
vault write auth/approle/role/aap-role \
    token_policies=lab-policy \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h

# Get credentials
vault read auth/approle/role/aap-role/role-id
vault write -f auth/approle/role/aap-role/secret-id
```

### Vault Policy

```hcl
# shared/vault-config/lab-policy.hcl

# AppRole authentication
path "auth/approle/role/aap-role/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/aap-role/secret-id" {
  capabilities = ["update"]
}

# SSH certificate signing
path "ssh-client-signer/sign/aap-role" {
  capabilities = ["create", "update"]
}

path "ssh-client-signer/issue/aap-role" {
  capabilities = ["create", "update"]
}
```

---

## AAP Credential Configuration

This demo uses **HashiCorp Vault Secret Lookup** credential type with playbook-based SSH key generation. This approach provides **true ephemeral keys** - Vault generates both the private key and signed certificate on each job run.

### Step 1: Create Vault Secret Lookup Credential

In AAP, go to **Resources → Credentials → Add**:

| Field | Value |
|-------|-------|
| **Name** | `Vault AppRole` |
| **Credential Type** | `HashiCorp Vault Secret Lookup` |
| **Server URL** | `https://your-vault.example.com:8200` |
| **AppRole role_id** | *(from `vault read auth/approle/role/aap-role/role-id`)* |
| **AppRole secret_id** | *(from `vault write -f auth/approle/role/aap-role/secret-id`)* |
| **Path to Auth** | `approle` |
| **API Version** | `v1` |

### Step 2: Create Job Template

In AAP, go to **Resources → Templates → Add → Job Template**:

| Field | Value |
|-------|-------|
| **Name** | `Vault SSH Demo` |
| **Inventory** | `Demo Inventory` (or create one) |
| **Project** | Your project with the playbook |
| **Playbook** | `playbooks/vault-ssh-configure.yml` |
| **Credentials** | Select `Vault AppRole` created above |
| **Extra Variables** | *(leave empty - Terraform passes these)* |

### How It Works

1. Terraform triggers AAP job with `target_hosts`, `vault_addr`, `vault_ssh_role`, `ssh_user`
2. AAP injects `vault_approle_role_id` and `vault_approle_secret_id` from the credential
3. Playbook authenticates to Vault using AppRole
4. Playbook calls Vault `/issue/` endpoint → Vault generates ephemeral private key + signed cert
5. Playbook uses `ansible.netcommon.cli_command` or writes keys to temp file and SSHs to target
6. Keys are discarded after playbook completes

**No static SSH keys stored anywhere** - true zero-trust.

---

## Security Considerations

### Certificate TTL

The default TTL is 30 minutes. Consider:
- **Shorter TTL** (5-15 min) for high-security environments
- **Longer TTL** (1-4 hours) for long-running playbooks
- Balance security vs. operational needs

### Principal Restrictions

Configure `allowed_users` to restrict which usernames can be in certificates:
```bash
vault write ssh-client-signer/roles/aap-role allowed_users="ansible,deploy"
```

### Network Security

- Vault should only be accessible from AAP controllers
- Use TLS for all Vault communications
- Consider using Vault namespaces for multi-tenant environments

### Audit Logging

Enable Vault audit logging to track all certificate issuance:
```bash
vault audit enable file file_path=/var/log/vault/audit.log
```

### AppRole Security

- Rotate secret_id regularly
- Use `secret_id_num_uses` to limit secret reuse
- Consider using response wrapping for secret_id delivery

---

## Deployment Patterns

### Pattern 1: Centralized Vault

Single Vault cluster serves all AAP controllers and target environments.

**Pros:** Simplified management, single audit point
**Cons:** Single point of failure, network dependencies

### Pattern 2: Vault per Environment

Separate Vault clusters for dev/staging/prod.

**Pros:** Environment isolation, independent scaling
**Cons:** More infrastructure to manage

### Pattern 3: Vault Enterprise with Namespaces

Single Vault Enterprise cluster with namespaces per team/environment.

**Pros:** Logical separation with physical efficiency
**Cons:** Requires Vault Enterprise license

---

## Troubleshooting

### Certificate Verification

Inspect a signed certificate:
```bash
ssh-keygen -Lf signed-cert.pub
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Permission denied | Invalid principal | Check `valid_principals` matches target user |
| Certificate expired | TTL exceeded | Request new certificate |
| CA key mismatch | Wrong CA key on target | Update `trusted-user-ca-keys.pem` |
| Vault auth failed | Invalid AppRole credentials | Verify role_id and secret_id |

### Debug SSH Connection

```bash
ssh -vvv -i private_key -i signed_cert.pub user@host
```
