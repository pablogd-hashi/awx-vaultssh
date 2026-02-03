# -----------------------------------------------------------------------------
# Vault Policy for AAP SSH Certificate Signing
#
# This policy grants AAP (Ansible Automation Platform) permissions to:
# 1. Authenticate via AppRole
# 2. Request signed SSH certificates
# 3. Read the SSH CA public key
#
# Apply this policy:
#   vault policy write aap-ssh-policy shared/vault-config/lab-policy.hcl
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AppRole Authentication
# -----------------------------------------------------------------------------

path "auth/approle/role/aap-role/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/aap-role/secret-id" {
  capabilities = ["update"]
}

# -----------------------------------------------------------------------------
# SSH Certificate Signing
# -----------------------------------------------------------------------------

# Sign an existing public key
path "ssh-client-signer/sign/aap-role" {
  capabilities = ["create", "update"]
}

# Issue a new key pair with signed certificate (ephemeral keys)
path "ssh-client-signer/issue/aap-role" {
  capabilities = ["create", "update"]
}

# -----------------------------------------------------------------------------
# SSH CA Public Key (for VM configuration)
# -----------------------------------------------------------------------------

path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}

path "ssh-client-signer/public_key" {
  capabilities = ["read"]
}

# -----------------------------------------------------------------------------
# Optional: Role Information (useful for debugging)
# -----------------------------------------------------------------------------

path "ssh-client-signer/roles/aap-role" {
  capabilities = ["read"]
}
