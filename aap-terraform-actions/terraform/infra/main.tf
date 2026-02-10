# Main Configuration
#
# AWS infrastructure for Vault SSH CA demo.
# Vault configuration is in vault.tf
# AAP integration is in aap.tf

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
# Compute VM
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

  # Vault SSH CA must be created before VMs (they need the CA public key)
  depends_on = [data.http.vault_ca_public_key]
}

# -----------------------------------------------------------------------------
# AAP Trigger
# -----------------------------------------------------------------------------
# Triggers Ansible configuration after VM is ready.
# Using terraform_data resource to bind action_trigger to module completion.

resource "terraform_data" "aap_trigger" {
  # Track VM IPs - if any change, re-trigger configuration
  input = join(",", module.vm.public_ips)

  depends_on = [module.vm]

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vm]
    }
  }
}
