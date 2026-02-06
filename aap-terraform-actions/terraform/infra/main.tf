# -----------------------------------------------------------------------------
# Main Configuration
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = { Name = "${var.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name_prefix}-public" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.name_prefix}-rt" }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Vault SSH CA
# -----------------------------------------------------------------------------

module "vault_ssh_ca" {
  source = "../modules/vault-ssh-ca"

  ssh_mount_path    = var.vault_ssh_mount
  ssh_role_name     = var.vault_ssh_role
  approle_role_name = "aap-${var.name_prefix}"
  allowed_users     = [var.ssh_user]
  default_user      = var.ssh_user
}

# -----------------------------------------------------------------------------
# VM
# -----------------------------------------------------------------------------

module "vm" {
  source = "../modules/vm"

  name_prefix       = var.name_prefix
  instance_count    = var.vm_count
  instance_type     = var.instance_type
  ami_name_filter   = var.ami_filter
  vpc_id            = aws_vpc.main.id
  subnet_id         = aws_subnet.public.id
  allowed_ssh_cidrs = var.allowed_cidrs
  ssh_user          = var.ssh_user

  depends_on = [module.vault_ssh_ca]
}

# -----------------------------------------------------------------------------
# AAP Inventory & Hosts
# -----------------------------------------------------------------------------

resource "aap_inventory" "main" {
  name        = "${var.name_prefix}-inventory"
  description = "Managed by Terraform"
}

resource "aap_host" "vm" {
  for_each = module.vm.inventory

  inventory_id = aap_inventory.main.id
  name         = each.key
  variables = jsonencode({
    ansible_host = each.value.ansible_host
    ansible_user = each.value.ansible_user
  })
}

# -----------------------------------------------------------------------------
# Terraform Action - Launch AAP Job
# -----------------------------------------------------------------------------

action "aap_job_launch" "configure_vms" {
  config {
    job_template_id     = var.aap_job_template_id
    wait_for_completion = true

    extra_vars = jsonencode({
      target_hosts            = join(",", module.vm.public_ips)
      ssh_user                = var.ssh_user
      vault_addr              = var.vault_addr
      vault_namespace         = var.vault_namespace
      vault_ssh_role          = module.vault_ssh_ca.ssh_role_name
      vault_approle_role_id   = module.vault_ssh_ca.approle_role_id
      vault_approle_secret_id = module.vault_ssh_ca.approle_secret_id
    })
  }
}

resource "terraform_data" "aap_trigger" {
  input = join(",", module.vm.public_ips)

  depends_on = [module.vm, aap_host.vm]

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vms]
    }
  }
}
