# -----------------------------------------------------------------------------
# Vault Policy for AAP SSH Certificate Signing
#
# This policy grants the AAP controller permissions to:
# 1. Authenticate via AppRole
# 2. Request signed SSH certificates
# 3. Read the SSH CA public key
#
# Apply this policy:
#   vault policy write aap-ssh-policy vault/configure-vm-policy.hcl
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# AppRole Authentication
# Allow reading the role-id and generating secret-ids
# -----------------------------------------------------------------------------

path "auth/approle/role/awx-role/role-id" {
  capabilities = ["read"]
}

path "auth/approle/role/awx-role/secret-id" {
  capabilities = ["update"]
}

# -----------------------------------------------------------------------------
# SSH Certificate Signing
# Allow signing and issuing SSH certificates
# -----------------------------------------------------------------------------

# Sign an existing public key
path "ssh-client-signer/sign/awx-role" {
  capabilities = ["create", "update"]
}

# Issue a new key pair with signed certificate
path "ssh-client-signer/issue/awx-role" {
  capabilities = ["create", "update"]
}

# -----------------------------------------------------------------------------
# SSH CA Public Key
# Allow reading the CA public key (needed for VM configuration)
# -----------------------------------------------------------------------------

path "ssh-client-signer/config/ca" {
  capabilities = ["read"]
}

path "ssh-client-signer/public_key" {
  capabilities = ["read"]
}

# -----------------------------------------------------------------------------
# Optional: Role Information
# Allow reading role configuration (useful for debugging)
# -----------------------------------------------------------------------------

path "ssh-client-signer/roles/awx-role" {
  capabilities = ["read"]
}
