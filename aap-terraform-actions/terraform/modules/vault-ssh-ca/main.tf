# -----------------------------------------------------------------------------
# Vault SSH CA Module
# -----------------------------------------------------------------------------
# Configures Vault SSH CA for AAP integration:
#   - SSH secrets engine with CA
#   - SSH role for certificate signing
#   - AppRole auth for AAP
#   - Policy with least-privilege access
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# SSH Secrets Engine
# -----------------------------------------------------------------------------

resource "vault_mount" "ssh" {
  path        = var.ssh_mount_path
  type        = "ssh"
  description = "SSH certificate authority for AAP"

  default_lease_ttl_seconds = 1800  # 30 minutes
  max_lease_ttl_seconds     = 86400 # 24 hours
}

resource "vault_ssh_secret_backend_ca" "ca" {
  backend              = vault_mount.ssh.path
  generate_signing_key = true
}

# -----------------------------------------------------------------------------
# SSH Role
# -----------------------------------------------------------------------------

resource "vault_ssh_secret_backend_role" "aap" {
  name                    = var.ssh_role_name
  backend                 = vault_mount.ssh.path
  key_type                = "ca"
  algorithm_signer        = "rsa-sha2-256"
  allow_user_certificates = true

  # User configuration
  allowed_users      = join(",", var.allowed_users)
  default_user       = var.default_user
  allow_user_key_ids = var.allow_user_key_ids

  # TTL configuration
  ttl     = var.default_ttl
  max_ttl = var.max_ttl

  # Extensions required for interactive SSH sessions
  allowed_extensions = "permit-pty,permit-user-rc,permit-port-forwarding"
  default_extensions = {
    "permit-pty"     = ""
    "permit-user-rc" = ""
  }

  # Key generation for Option B (ephemeral keys via /ssh/issue)
  allow_bare_domains = var.allow_key_generation
  allowed_domains    = var.allow_key_generation ? join(",", var.allowed_users) : ""

  depends_on = [vault_ssh_secret_backend_ca.ca]
}

# -----------------------------------------------------------------------------
# Policy - Least Privilege
# -----------------------------------------------------------------------------

resource "vault_policy" "aap_ssh" {
  name = "${var.approle_role_name}-policy"

  policy = <<-EOT
    # Sign SSH public keys (Option A: Vault Signed SSH)
    path "${var.ssh_mount_path}/sign/${var.ssh_role_name}" {
      capabilities = ["create", "update"]
    }

    # Issue SSH certificates with generated keys (Option B: ephemeral)
    path "${var.ssh_mount_path}/issue/${var.ssh_role_name}" {
      capabilities = ["create", "update"]
    }

    # Read CA public key (for verification)
    path "${var.ssh_mount_path}/config/ca" {
      capabilities = ["read"]
    }

    # Read public key endpoint (unauthenticated, but explicit)
    path "${var.ssh_mount_path}/public_key" {
      capabilities = ["read"]
    }
  EOT
}

# -----------------------------------------------------------------------------
# AppRole Auth
# -----------------------------------------------------------------------------

resource "vault_auth_backend" "approle" {
  type = "approle"
  path = var.approle_path
}

resource "vault_approle_auth_backend_role" "aap" {
  backend        = vault_auth_backend.approle.path
  role_name      = var.approle_role_name
  token_policies = [vault_policy.aap_ssh.name]

  # Token settings
  token_ttl     = 3600  # 1 hour
  token_max_ttl = 14400 # 4 hours

  # Security settings
  secret_id_bound_cidrs = []
  token_bound_cidrs     = []
  secret_id_num_uses    = 0 # Unlimited (rotate via Terraform)
  token_num_uses        = 0 # Unlimited
}

resource "vault_approle_auth_backend_role_secret_id" "aap" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.aap.role_name

  metadata = jsonencode({
    source  = "terraform"
    purpose = "aap-ssh-ca"
  })
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "vault_approle_auth_backend_role_id" "aap" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.aap.role_name
}
