terraform {
  required_version = ">= 1.14.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
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
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "vault" {
  address = var.vault_addr
  # Authentication handled via VAULT_TOKEN environment variable
  # or configure auth method here
}

provider "aap" {
  host  = var.aap_host
  token = var.aap_token
}
