# Vault SSH CA with Ansible Automation Platform

This repository demonstrates how to manage SSH credentials at scale using **HashiCorp Vault's SSH Certificate Authority (CA)** integrated with **Ansible Automation Platform (AAP)**.

Based on the HashiCorp blog post: [Managing Ansible Automation Platform (AAP) Credentials at Scale with Vault](https://www.hashicorp.com/en/blog/managing-ansible-automation-platform-aap-credentials-at-scale-with-vault)

## Overview

Traditional SSH key management becomes unmanageable at scale. This solution uses Vault as a central SSH CA to:

- **Eliminate static SSH keys** - No more distributing and rotating keys across hundreds of servers
- **Short-lived certificates** - SSH certificates expire automatically (default: 30 minutes)
- **Centralized audit** - All certificate issuance is logged in Vault
- **Dynamic credentials** - AAP requests fresh certificates before each job run

## Choose Your Approach

This repository provides **two deployment options** depending on your environment and requirements:

| Option | Best For | Components |
|--------|----------|------------|
| [**AAP + Terraform Actions**](./aap-terraform-actions/) | Enterprise production deployments | Red Hat AAP, Terraform 1.14+, Cloud VMs |
| [**AWX + Minikube**](./awx-minikube-poc/) | Quick proof-of-concept, learning | AWX (free), Minikube, Docker containers |

---

## Option 1: AAP with Terraform Actions (Enterprise)

**Location:** [`aap-terraform-actions/`](./aap-terraform-actions/)

This approach uses **Terraform Actions** (introduced in Terraform 1.14) to orchestrate the complete workflow:

1. Terraform provisions a VM in your cloud provider
2. Terraform triggers AAP via Actions after VM creation
3. AAP authenticates to Vault using AppRole
4. Vault issues a short-lived SSH certificate
5. AAP connects to the new VM and installs a demo Streamlit application

**Key Features:**
- Uses Terraform Actions for declarative post-provisioning triggers
- Integrates with Red Hat Ansible Automation Platform (enterprise)
- Designed for cloud deployments (GCP, AWS, Azure)
- Production-ready credential management

**Requirements:**
- Terraform 1.14+
- Red Hat Ansible Automation Platform subscription
- HashiCorp Vault server
- Cloud provider account (GCP, AWS, or Azure)

---

## Option 2: AWX with Minikube (Quick PoC)

**Location:** [`awx-minikube-poc/`](./awx-minikube-poc/)

This approach provides a local, self-contained environment for testing and learning:

1. Deploy Vault and AWX in Minikube
2. Create Docker containers as target "VMs"
3. Configure Vault SSH CA and AWX credentials
4. Run playbooks using Vault-signed SSH certificates

**Key Features:**
- Runs entirely on your local machine
- Uses AWX (free, open-source Ansible Tower)
- Docker containers simulate target VMs
- Perfect for demos and proof-of-concepts

**Requirements:**
- macOS or Linux
- Minikube, Docker, Helm, kubectl
- Local Vault installation

---

## Architecture

For detailed architecture documentation, see [docs.md](./docs.md).

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

## Shared Components

Common Vault configurations used by both approaches are in [`shared/`](./shared/):

- **Vault Policy** - AppRole permissions for SSH signing
- **SSH Role Configuration** - Certificate parameters and allowed principals

## Quick Start

### For Enterprise (AAP + Terraform)
```bash
cd aap-terraform-actions
# Configure your variables
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Deploy
terraform -chdir=terraform init && terraform -chdir=terraform apply
```

### For Quick PoC (AWX + Minikube)
```bash
cd awx-minikube-poc
# Start Minikube and deploy
minikube start --driver=docker
./setup.sh  # Coming soon - or follow the README
```

## Prerequisites

Before starting, ensure you have a Vault server running with:
- SSH secrets engine enabled at `ssh-client-signer`
- AppRole authentication configured
- The AAP/AWX `HashiCorp Vault Signed SSH` credential type configured

See [docs.md](./docs.md) for Vault setup instructions.

## License

This project is provided as-is for educational and demonstration purposes.
