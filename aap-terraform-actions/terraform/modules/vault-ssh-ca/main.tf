# Vault SSH CA Configuration
#
# Provisions Vault SSH CA infrastructure:
#   - SSH secrets engine
#   - SSH CA signing key
#   - SSH role for certificate issuance
#   - AppRole auth method
#   - Policy for SSH certificate issuance
#
# Vault resources are idempotent - safe to run against pre-configured Vault.

# -----------------------------------------------------------------------------
# SSH Secrets Engine
# -----------------------------------------------------------------------------

resource "vault_mount" "ssh" {
  path        = var.ssh_mount_path
  type        = "ssh"
  description = "SSH certificate signing for AAP"
}

resource "vault_ssh_secret_backend_ca" "ssh_ca" {
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}

# -----------------------------------------------------------------------------
# SSH Role for Certificate Issuance
# -----------------------------------------------------------------------------

resource "vault_ssh_secret_backend_role" "aap" {
  name                    = var.ssh_role_name
  backend                 = vault_mount.ssh.path
  key_type                = "ca"
  algorithm_signer        = "rsa-sha2-256"
  allow_user_certificates = true
  allowed_users           = join(",", var.allowed_users)
  default_user            = var.default_user
  ttl                     = var.default_ttl
  max_ttl                 = var.max_ttl

  # CRITICAL: permit-pty is required for SSH sessions to work
  allowed_extensions = "permit-pty,permit-user-rc,permit-port-forwarding"
  default_extensions = {
    "permit-pty"     = ""
    "permit-user-rc" = ""
  }

  depends_on = [vault_ssh_secret_backend_ca.ssh_ca]
}

# -----------------------------------------------------------------------------
# AppRole Auth Method
# -----------------------------------------------------------------------------

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = "approle"
}

# Policy allowing SSH certificate issuance
resource "vault_policy" "ssh_issue" {
  name = "${var.approle_role_name}-ssh-issue"

  policy = <<-EOT
    # Allow issuing SSH certificates (generates key + signs)
    path "${var.ssh_mount_path}/issue/${var.ssh_role_name}" {
      capabilities = ["create", "update"]
    }

    # Allow signing SSH keys (signs existing key)
    path "${var.ssh_mount_path}/sign/${var.ssh_role_name}" {
      capabilities = ["create", "update"]
    }
  EOT
}

resource "vault_approle_auth_backend_role" "aap" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.approle_role_name
  token_policies = [vault_policy.ssh_issue.name]
  token_ttl      = 3600
  token_max_ttl  = 7200
}

resource "vault_approle_auth_backend_role_secret_id" "aap" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.aap.role_name
}

# -----------------------------------------------------------------------------
# CA Public Key (for VM trust configuration)
# -----------------------------------------------------------------------------

data "vault_generic_secret" "ca_public_key" {
  path = "${vault_mount.ssh.path}/config/ca"

  depends_on = [vault_ssh_secret_backend_ca.ssh_ca]
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

locals {
  vault_ca_public_key     = data.vault_generic_secret.ca_public_key.data["public_key"]
  vault_approle_role_id   = vault_approle_auth_backend_role.aap.role_id
  vault_approle_secret_id = vault_approle_auth_backend_role_secret_id.aap.secret_id
  vault_ssh_role_name     = vault_ssh_secret_backend_role.aap.name
}
