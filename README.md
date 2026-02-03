# AAP Vault SSH CA

Manage SSH credentials at scale using **HashiCorp Vault's SSH Certificate Authority (CA)** integrated with **Ansible Automation Platform (AAP)**.

Based on the HashiCorp blog post: [Managing Ansible Automation Platform (AAP) Credentials at Scale with Vault](https://www.hashicorp.com/en/blog/managing-ansible-automation-platform-aap-credentials-at-scale-with-vault)

## Overview

Traditional SSH key management becomes unmanageable at scale. This solution uses Vault as a central SSH CA to:

- **Eliminate static SSH keys** - No more distributing and rotating keys across hundreds of servers
- **Short-lived certificates** - SSH certificates expire automatically (default: 30 minutes)
- **Centralized audit** - All certificate issuance is logged in Vault
- **Dynamic credentials** - AAP requests fresh certificates before each job run

## Choose Your Approach

This repository provides **two deployment options** depending on your environment:

| Option | Best For | Components |
|--------|----------|------------|
| [**AAP + Terraform Actions**](./aap-terraform-actions/) | Enterprise production deployments | Red Hat AAP, Terraform 1.14+, GCP/AWS VMs |
| [**AWX + Minikube**](./awx-minikube-poc/) | Quick proof-of-concept, learning | AWX (free), Minikube, Docker containers |

---

## Option 1: AAP with Terraform Actions (Enterprise)

**Location:** [`aap-terraform-actions/`](./aap-terraform-actions/)

Uses **Terraform Actions** (Terraform 1.14+) to orchestrate:

1. Terraform provisions a VM in GCP
2. Terraform triggers AAP via Actions after VM creation
3. AAP authenticates to Vault using AppRole
4. Vault issues ephemeral SSH certificate
5. AAP connects to the VM and configures it

**Requirements:**
- Terraform 1.14+
- Red Hat Ansible Automation Platform
- HashiCorp Vault with SSH CA
- GCP or AWS account

```bash
cd aap-terraform-actions
task check    # Verify prerequisites
task setup    # Initialize Terraform
task apply    # Deploy and trigger AAP
```

---

## Option 2: AWX with Minikube (Quick PoC)

**Location:** [`awx-minikube-poc/`](./awx-minikube-poc/)

Local, self-contained environment for testing:

1. Deploy Vault and AWX in Minikube
2. Docker containers as target "VMs"
3. Configure Vault SSH CA and AWX credentials
4. Run playbooks with Vault-signed certificates

**Requirements:**
- macOS or Linux
- Minikube, Docker, Helm, kubectl
- Local Vault installation

---

## Architecture

```
                              ┌─────────────────┐
                              │  HashiCorp      │
                              │     Vault       │
                              │   (SSH CA)      │
                              └────────┬────────┘
                                       │
                     ┌─────────────────┼─────────────────┐
                     │                 │                 │
                     ▼                 │                 ▼
          ┌──────────────────┐         │      ┌──────────────────┐
          │   AAP/AWX        │◄────────┘      │  Target VMs      │
          │   Controller     │                │  (trust CA)      │
          └──────────────────┘                └──────────────────┘
                     │                                 ▲
                     │                                 │
                     └─────────────────────────────────┘
                          SSH with signed certificate
```

For detailed architecture, see [docs.md](./docs.md).

## Vault Setup

Before using either option, configure Vault:

```bash
# Enable SSH secrets engine
vault secrets enable -path=ssh-client-signer ssh

# Generate CA key pair
vault write ssh-client-signer/config/ca generate_signing_key=true

# Create signing role
vault write ssh-client-signer/roles/aap-role \
    algorithm_signer=rsa-sha2-256 \
    allow_user_certificates=true \
    allowed_users="*" \
    default_user="rhel" \
    ttl=30m

# Enable AppRole auth
vault auth enable approle

# Create AppRole for AAP
vault write auth/approle/role/aap-role \
    token_policies=aap-ssh-policy \
    token_ttl=1h

# Apply policy
vault policy write aap-ssh-policy shared/vault-config/lab-policy.hcl

# Get credentials for AAP
vault read auth/approle/role/aap-role/role-id
vault write -f auth/approle/role/aap-role/secret-id
```

## Shared Components

Common configurations in [`shared/`](./shared/):

- **[lab-policy.hcl](./shared/vault-config/lab-policy.hcl)** - Vault policy for AppRole + SSH signing
- **[get_ssh_keys.yml](./shared/vault-config/get_ssh_keys.yml)** - Example playbook to retrieve SSH keys

## License

This project is provided as-is for educational and demonstration purposes.
