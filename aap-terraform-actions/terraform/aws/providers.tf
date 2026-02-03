# -----------------------------------------------------------------------------
# Terraform Providers - AWS
# -----------------------------------------------------------------------------

terraform {
  required_version = ">= 1.14.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    aap = {
      source  = "ansible/aap"
      version = "~> 1.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aap-terraform-actions"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

provider "vault" {
  address         = var.vault_addr
  token           = var.vault_token
  namespace       = var.vault_namespace != "" ? var.vault_namespace : null
  skip_tls_verify = var.vault_skip_tls_verify
}

provider "aap" {
  host     = var.aap_host
  username = var.aap_username
  password = var.aap_password
}
