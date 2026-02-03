# -----------------------------------------------------------------------------
# Provider Configuration - Infrastructure
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

provider "vault" {
  address   = var.vault_address
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
}

provider "aap" {
  host                 = var.aap_host
  username             = var.aap_username
  password             = var.aap_password
  insecure_skip_verify = true
}
