# -----------------------------------------------------------------------------
# Packer - Golden VM Image with Vault SSH CA
#
# Builds an AWS AMI (RHEL 9) with Vault SSH CA public key pre-configured.
# VMs launched from this image trust certificates signed by Vault.
# -----------------------------------------------------------------------------

packer {
  required_plugins {
    amazon = {
      version = "~> 1"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

source "amazon-ebs" "rhel9-vault-ssh" {
  ami_name      = "${var.ami_name_prefix}-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region

  source_ami_filter {
    filters = {
      name                = "RHEL-9.*_HVM-*-x86_64-*-Hourly2-GP3"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["309956199498"] # Red Hat official
  }

  ssh_username = "ec2-user"

  tags = {
    Name        = "${var.ami_name_prefix}-${local.timestamp}"
    BuildDate   = local.timestamp
    Description = "RHEL 9 with Vault SSH CA configured"
    VaultCA     = "true"
  }

  # VPC configuration (optional - uses default VPC if not specified)
  # vpc_id    = var.vpc_id
  # subnet_id = var.subnet_id
}

build {
  name    = "vault-ssh-golden-image"
  sources = ["source.amazon-ebs.rhel9-vault-ssh"]

  # Wait for cloud-init to complete
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true",
      "echo 'Cloud-init complete.'"
    ]
  }

  # Install required packages and pre-install Streamlit (skip full update for faster builds)
  provisioner "shell" {
    inline = [
      "echo 'Installing required packages...'",
      "sudo dnf install -y python3 python3-pip openssh-server",

      "echo 'Pre-installing Streamlit and dependencies...'",
      "sudo mkdir -p /opt/streamlit-demo",
      "sudo python3 -m venv /opt/streamlit-demo/venv",
      "sudo /opt/streamlit-demo/venv/bin/pip install --upgrade pip",
      "sudo /opt/streamlit-demo/venv/bin/pip install streamlit pandas plotly"
    ]
  }

  # Upload Vault SSH CA public key
  provisioner "file" {
    content     = var.vault_ssh_ca_public_key
    destination = "/tmp/trusted-user-ca-keys.pem"
  }

  # Configure SSH to trust Vault CA
  provisioner "shell" {
    inline = [
      "echo 'Installing Vault SSH CA public key...'",
      "sudo mv /tmp/trusted-user-ca-keys.pem /etc/ssh/trusted-user-ca-keys.pem",
      "sudo chmod 644 /etc/ssh/trusted-user-ca-keys.pem",
      "sudo chown root:root /etc/ssh/trusted-user-ca-keys.pem",

      "echo 'Configuring SSHD to trust Vault CA...'",
      "sudo grep -q '^TrustedUserCAKeys' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' | sudo tee -a /etc/ssh/sshd_config",

      "echo 'Validating SSHD configuration...'",
      "sudo sshd -t",

      "echo 'Restarting SSHD...'",
      "sudo systemctl restart sshd",
      "sudo systemctl enable sshd",

      "echo 'Verifying SSHD is running...'",
      "sudo systemctl status sshd --no-pager",

      "echo 'Vault SSH CA configuration complete!'"
    ]
  }

  # Create ansible user for AAP
  provisioner "shell" {
    inline = [
      "echo 'Creating ansible user...'",
      "sudo useradd -m -s /bin/bash ${var.ssh_user} || true",
      "sudo mkdir -p /home/${var.ssh_user}/.ssh",
      "sudo chmod 700 /home/${var.ssh_user}/.ssh",
      "sudo chown -R ${var.ssh_user}:${var.ssh_user} /home/${var.ssh_user}/.ssh",

      "echo 'Configuring sudo for ansible user...'",
      "echo '${var.ssh_user} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${var.ssh_user}",
      "sudo chmod 440 /etc/sudoers.d/${var.ssh_user}",

      "echo 'Ansible user setup complete!'"
    ]
  }

  # Final cleanup
  provisioner "shell" {
    inline = [
      "echo 'Final cleanup...'",
      "sudo dnf clean all",
      "sudo rm -rf /var/cache/dnf/*",
      "echo 'Golden image build complete!'"
    ]
  }
}
