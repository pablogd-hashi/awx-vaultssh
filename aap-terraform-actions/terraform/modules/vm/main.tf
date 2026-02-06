# -----------------------------------------------------------------------------
# VM Module - Main Configuration
# -----------------------------------------------------------------------------
# Creates EC2 instances from a golden image with Vault SSH CA pre-configured.
# Supports both static AMI ID and dynamic AMI lookup via name filter.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_ami" "golden" {
  count       = var.ami_id == "" ? 1 : 0
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# -----------------------------------------------------------------------------
# Locals
# -----------------------------------------------------------------------------

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.golden[0].id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "vm" {
  name_prefix = "${var.name_prefix}-vm-sg-"
  description = "Security group for ${var.name_prefix} VMs"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vm-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# SSH access
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.vm.id
  description       = "SSH from ${each.value}"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

# Application port (conditional)
resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each = var.app_port > 0 ? toset(var.allowed_ssh_cidrs) : toset([])

  security_group_id = aws_security_group.vm.id
  description       = "Application port ${var.app_port} from ${each.value}"
  from_port         = var.app_port
  to_port           = var.app_port
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

# All outbound traffic
resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.vm.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_instance" "vm" {
  count = var.instance_count

  ami                         = local.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.vm.id]
  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
    encrypted             = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2
    http_put_response_hop_limit = 1
  }

  tags = merge(var.tags, {
    Name = var.instance_count > 1 ? "${var.name_prefix}-vm-${count.index + 1}" : "${var.name_prefix}-vm"
  })

  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates
  }
}
