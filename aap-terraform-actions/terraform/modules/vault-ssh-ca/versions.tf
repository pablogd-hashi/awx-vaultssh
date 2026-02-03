# -----------------------------------------------------------------------------
# Terraform Configuration - Vault SSH CA Module
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.0.0, < 5.0.0"
    }
  }
}
