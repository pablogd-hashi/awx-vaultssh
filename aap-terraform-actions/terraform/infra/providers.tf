# -----------------------------------------------------------------------------
# Providers
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

provider "vault" {
  address   = var.vault_addr
  token     = var.vault_token != "" ? var.vault_token : null
  namespace = var.vault_namespace != "" ? var.vault_namespace : null
}

provider "aap" {
  host                 = var.aap_host
  username             = var.aap_username
  password             = var.aap_password
  insecure_skip_verify = true
}
