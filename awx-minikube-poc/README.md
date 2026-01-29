# AWX + Minikube Proof of Concept

This folder contains a complete proof-of-concept environment for testing Vault SSH CA integration with AWX (the open-source version of Ansible Tower).

## Overview

This PoC runs entirely on your local machine using:
- **Minikube** - Local Kubernetes cluster
- **Vault** - Deployed via Helm in Minikube
- **AWX** - Deployed via the AWX Operator
- **Docker containers** - Simulated target VMs

## Prerequisites

- macOS or Linux
- Docker Desktop
- Minikube (`brew install minikube`)
- Helm (`brew install helm`)
- kubectl (`brew install kubectl`)
- jq (`brew install jq`)

## Quick Start

### Step 1: Start Minikube

```bash
minikube start --driver=docker
```

### Step 2: Deploy Vault

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Create namespace and install Vault
kubectl create ns vault
helm install vault hashicorp/vault -n vault

# Initialize and unseal Vault
kubectl exec -n vault vault-0 -- sh -c \
  "vault operator init -key-shares=1 -key-threshold=1 -format=json" | tee init.json

kubectl exec -n vault vault-0 -- sh -c \
  "vault operator unseal $(jq -r '.unseal_keys_b64[0]' init.json)"

# Port forward Vault
kubectl port-forward -n vault svc/vault 8200:8200 &

# Set environment variables
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=$(jq -r .root_token init.json)
```

### Step 3: Configure Vault SSH CA

```bash
# Enable SSH secrets engine
vault secrets enable -path=ssh-client-signer ssh

# Generate CA key pair
vault write ssh-client-signer/config/ca generate_signing_key=true

# Create signing role
vault write ssh-client-signer/roles/awx-role - <<EOF
{
  "algorithm_signer": "rsa-sha2-256",
  "allow_user_certificates": true,
  "allowed_users": "*",
  "allowed_extensions": "permit-pty,permit-port-forwarding",
  "default_extensions": {"permit-pty": ""},
  "key_type": "ca",
  "default_user": "rhel,ubuntu",
  "ttl": "30m0s"
}
EOF

# Enable AppRole authentication
vault auth enable approle

# Apply policy
vault policy write lab-policy ../shared/vault-config/lab-policy.hcl

# Create AppRole for AWX
vault write auth/approle/role/awx-role \
    token_policies=lab-policy \
    token_ttl=1h \
    token_max_ttl=4h \
    secret_id_ttl=24h

# Get credentials (save these!)
vault read auth/approle/role/awx-role/role-id | tee role-id.txt
vault write -f auth/approle/role/awx-role/secret-id | tee secret-id.txt
```

### Step 4: Create Docker Target VMs

```bash
# Build the SSH-enabled Docker image
docker build -t awx-ssh -f docker/Dockerfile docker/

# Get Vault's CA public key
curl -k -o trusted-user-ca-keys.pem $VAULT_ADDR/v1/ssh-client-signer/public_key

# Create Docker network
docker network create --subnet=192.168.1.0/24 awx-network

# Create target containers
docker run -d --name vm1 --network awx-network -p 12222:22 \
  -v $(pwd)/trusted-user-ca-keys.pem:/etc/ssh/trusted-user-ca-keys.pem:ro awx-ssh

docker run -d --name vm2 --network awx-network -p 12223:22 \
  -v $(pwd)/trusted-user-ca-keys.pem:/etc/ssh/trusted-user-ca-keys.pem:ro awx-ssh

docker run -d --name vm3 --network awx-network -p 12224:22 \
  -v $(pwd)/trusted-user-ca-keys.pem:/etc/ssh/trusted-user-ca-keys.pem:ro awx-ssh
```

### Step 5: Test SSH Access Manually

```bash
# Request signed certificate
vault write -format json ssh-client-signer/issue/awx-role \
  valid_principals="rhel,ubuntu" | tee ssh-keys.json

# Extract keys
jq -r .data.private_key ssh-keys.json > mypkey
jq -r .data.signed_key ssh-keys.json > mypkey-cert.pub
chmod 600 mypkey mypkey-cert.pub

# Test SSH connection
ssh -i mypkey -i mypkey-cert.pub rhel@localhost -p 12222
```

### Step 6: Deploy AWX

```bash
# Deploy the AWX operator
cd operator/awx-operator
make deploy

# Wait for operator to be ready
kubectl get pods -n awx -w

# Deploy AWX instance
kubectl apply -k .

# Get admin password
kubectl get secret -n awx awx-demo-admin-password -o jsonpath='{.data.password}' | base64 -d

# Port forward AWX UI
kubectl port-forward -n awx svc/awx-demo-service 8080:80
```

Access AWX at http://localhost:8080 (username: admin)

### Step 7: Configure AWX Credentials

1. **Create HashiCorp Vault Signed SSH credential:**
   - Credential Type: HashiCorp Vault Signed SSH
   - Vault Server URL: http://host.docker.internal:8200 (or your Vault URL)
   - Role ID: (from role-id.txt)
   - Secret ID: (from secret-id.txt)

2. **Create Machine credential:**
   - Credential Type: Machine
   - Username: rhel
   - SSH Private Key: (paste a private key)
   - Signed SSH Certificate: Link to the Vault credential above

3. **Create Inventory with your Docker containers:**
   ```
   [docker_vms]
   vm1 ansible_host=host.docker.internal ansible_port=12222
   vm2 ansible_host=host.docker.internal ansible_port=12223
   vm3 ansible_host=host.docker.internal ansible_port=12224
   ```

4. **Create and run a Job Template** using your credentials and inventory

## Folder Structure

```
awx-minikube-poc/
├── README.md              # This file
├── docker/
│   └── Dockerfile         # SSH-enabled Fedora container
├── multipass/
│   └── config.yaml        # Cloud-init for Multipass VMs (alternative)
├── operator/
│   └── awx-operator/      # AWX Kubernetes operator
├── playbooks/
│   ├── aap-install-vault-demo-playbook.yml
│   ├── get_ssh_keys.yml
│   └── vault_ssh_connect.yml
└── images/
    └── *.png              # Screenshots for documentation
```

## Cleanup

```bash
# Stop Docker containers
docker stop vm1 vm2 vm3
docker rm vm1 vm2 vm3
docker network rm awx-network

# Delete Minikube cluster
minikube delete
```

## Troubleshooting

### SSH Connection Fails

1. Check that the CA key is mounted in the container:
   ```bash
   docker exec vm1 cat /etc/ssh/trusted-user-ca-keys.pem
   ```

2. Verify the certificate is valid:
   ```bash
   ssh-keygen -Lf mypkey-cert.pub
   ```

3. Check SSH daemon logs:
   ```bash
   docker logs vm1
   ```

### Vault Connection Issues

1. Verify Vault is unsealed:
   ```bash
   vault status
   ```

2. Check port forwarding is active:
   ```bash
   kubectl port-forward -n vault svc/vault 8200:8200
   ```

### AWX Cannot Reach Docker Containers

When running in Minikube, AWX needs to reach Docker containers on the host. Use:
- `host.docker.internal` (macOS/Windows)
- `172.17.0.1` (Linux, default Docker bridge)

You may also need to run `minikube tunnel` in a separate terminal.
