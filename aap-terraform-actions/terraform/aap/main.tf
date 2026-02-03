# -----------------------------------------------------------------------------
# AAP Controller Deployment
# -----------------------------------------------------------------------------
# Deploys Ansible Automation Platform using pre-built AMIs.
# AMIs are maintained in rts-aap-demo and include AAP pre-installed with license.
# -----------------------------------------------------------------------------

locals {
  # Pre-built AAP AMIs by region (from rts-aap-demo)
  aap_amis = {
    "us-east-1"      = "ami-09758fd69558336ec"
    "eu-central-1"   = "ami-0f6536ad0b5a0a6a9"
    "ap-southeast-1" = "ami-0efd6a38242c8917e"
    "ap-south-1"     = "ami-076833edc1679a270"
  }

  common_tags = merge(var.tags, {
    Project   = "aap-terraform-actions"
    Component = "aap-controller"
    ManagedBy = "terraform"
  })
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

# -----------------------------------------------------------------------------
# SSH Key Pair
# -----------------------------------------------------------------------------

resource "tls_private_key" "aap" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "aap" {
  key_name   = "${var.name_prefix}-key"
  public_key = tls_private_key.aap.public_key_openssh

  tags = {
    Name = "${var.name_prefix}-key"
  }
}

# -----------------------------------------------------------------------------
# VPC and Networking
# -----------------------------------------------------------------------------

resource "aws_vpc" "aap" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.name_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "aap" {
  vpc_id = aws_vpc.aap.id

  tags = {
    Name = "${var.name_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.aap.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.name_prefix}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.aap.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aap.id
  }

  tags = {
    Name = "${var.name_prefix}-public-rtb"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------------------------------------------------------
# Security Group
# -----------------------------------------------------------------------------

resource "aws_security_group" "aap" {
  name        = "${var.name_prefix}-sg"
  description = "Security group for AAP Controller"
  vpc_id      = aws_vpc.aap.id

  tags = {
    Name = "${var.name_prefix}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "https" {
  for_each = toset(var.allowed_https_cidrs)

  security_group_id = aws_security_group.aap.id
  description       = "HTTPS from ${each.value}"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  for_each = toset(var.allowed_https_cidrs)

  security_group_id = aws_security_group.aap.id
  description       = "HTTP from ${each.value}"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = toset(var.allowed_ssh_cidrs)

  security_group_id = aws_security_group.aap.id
  description       = "SSH from ${each.value}"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = each.value
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.aap.id
  description       = "Allow all outbound"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# -----------------------------------------------------------------------------
# AAP Controller Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "aap" {
  ami                         = local.aap_amis[var.aws_region]
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.aap.key_name
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.aap.id]
  associate_public_ip_address = true

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

  tags = {
    Name = "${var.name_prefix}-controller"
  }

  lifecycle {
    ignore_changes = [ami] # Don't replace on AMI updates
  }
}
