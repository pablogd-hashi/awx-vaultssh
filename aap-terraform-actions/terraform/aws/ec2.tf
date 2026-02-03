# -----------------------------------------------------------------------------
# AWS EC2 Instances
#
# Creates VMs using the golden image with Vault SSH CA pre-configured.
# The VMs trust certificates signed by Vault's SSH CA.
# -----------------------------------------------------------------------------

# Find the latest golden image (if ami_id not specified)
data "aws_ami" "golden_image" {
  count = var.ami_id == "" ? 1 : 0

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

locals {
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.golden_image[0].id
}

# IAM Role for EC2 instances (for SSM access)
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy" "ssm" {
  name = "AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "vm" {
  name_prefix        = "${var.resource_prefix}-vm-"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json

  tags = {
    Name = "${var.resource_prefix}-vm-role"
  }
}

resource "aws_iam_instance_profile" "vm" {
  name_prefix = "${var.resource_prefix}-vm-"
  role        = aws_iam_role.vm.name

  tags = {
    Name = "${var.resource_prefix}-vm-profile"
  }
}

resource "aws_iam_role_policy_attachment" "vm_ssm" {
  policy_arn = data.aws_iam_policy.ssm.arn
  role       = aws_iam_role.vm.name
}

# -----------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_instance" "vm" {
  count = var.vm_count

  ami                         = local.ami_id
  instance_type               = var.instance_type
  iam_instance_profile        = aws_iam_instance_profile.vm.name
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.vm.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required" # Enforces IMDSv2
  }

  tags = {
    Name           = "${var.resource_prefix}-vm-${count.index + 1}"
    VaultSSHCA     = "true"
    CredentialMode = var.credential_option == "A" ? "ephemeral" : "signed"
  }

  depends_on = [
    aws_internet_gateway.main,
    aws_route_table_association.public,
  ]
}

# -----------------------------------------------------------------------------
# Outputs for EC2
# -----------------------------------------------------------------------------

locals {
  vm_ips    = aws_instance.vm[*].public_ip
  vm_ids    = aws_instance.vm[*].id
  vm_names  = aws_instance.vm[*].tags["Name"]
}
