# -----------------------------------------------------------------------------
# Packer - AAP Controller Image (AWS/RHEL 9)
#
# Builds an AWS AMI with Red Hat Ansible Automation Platform pre-installed.
# This image can be used to quickly spin up AAP controllers.
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

source "amazon-ebs" "rhel9-aap" {
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

  # AAP needs more resources
  launch_block_device_mappings {
    device_name           = "/dev/sda1"
    volume_size           = var.disk_size
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name        = "${var.ami_name_prefix}-${local.timestamp}"
    BuildDate   = local.timestamp
    Description = "RHEL 9 with Ansible Automation Platform ${var.aap_version}"
    AAP_Version = var.aap_version
  }
}

build {
  name    = "aap-controller-build"
  sources = ["source.amazon-ebs.rhel9-aap"]

  # Wait for cloud-init
  provisioner "shell" {
    inline = [
      "echo 'Waiting for cloud-init to complete...'",
      "sudo cloud-init status --wait || true"
    ]
  }

  # Install prerequisites
  provisioner "shell" {
    inline = [
      "echo 'Installing prerequisites...'",
      "sudo dnf update -y",
      "sudo dnf install -y podman python3 python3-pip wget curl tar gzip"
    ]
  }

  # Upload AAP setup bundle (if local file provided)
  provisioner "file" {
    source      = var.aap_setup_bundle_path
    destination = "/tmp/aap-setup-bundle.tar.gz"
  }

  # Upload inventory template
  provisioner "file" {
    content = templatefile("${path.root}/inventory.pkrtpl.hcl", {
      aap_admin_password = var.aap_admin_password
      aap_hostname       = var.aap_hostname
    })
    destination = "/tmp/inventory"
  }

  # Upload bootstrap script
  provisioner "file" {
    source      = "${path.root}/bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }

  # Extract bundle and prepare AAP installation
  provisioner "shell" {
    inline = [
      "echo 'Preparing AAP installation...'",
      "sudo mkdir -p /opt/aap",
      "sudo tar -xzf /tmp/aap-setup-bundle.tar.gz -C /opt/aap --strip-components=1",
      "sudo mv /tmp/inventory /opt/aap/inventory",
      "sudo chmod +x /tmp/bootstrap.sh",
      "echo 'AAP preparation complete. Run bootstrap.sh on first boot to complete installation.'"
    ]
  }

  # Create systemd service for first-boot installation
  provisioner "shell" {
    inline = [
      "echo 'Creating first-boot service...'",
      "sudo tee /etc/systemd/system/aap-install.service > /dev/null <<'EOF'",
      "[Unit]",
      "Description=AAP First Boot Installation",
      "After=network-online.target",
      "Wants=network-online.target",
      "ConditionPathExists=!/opt/aap/.installed",
      "",
      "[Service]",
      "Type=oneshot",
      "ExecStart=/bin/bash /tmp/bootstrap.sh",
      "ExecStartPost=/bin/touch /opt/aap/.installed",
      "RemainAfterExit=yes",
      "StandardOutput=journal",
      "StandardError=journal",
      "",
      "[Install]",
      "WantedBy=multi-user.target",
      "EOF",
      "sudo systemctl daemon-reload",
      "sudo systemctl enable aap-install.service"
    ]
  }

  # Optional: Install Vault SSH CA support
  provisioner "file" {
    content     = var.vault_ssh_ca_public_key
    destination = "/tmp/trusted-user-ca-keys.pem"
  }

  provisioner "shell" {
    inline = [
      "if [ -s /tmp/trusted-user-ca-keys.pem ]; then",
      "  echo 'Installing Vault SSH CA public key...'",
      "  sudo mv /tmp/trusted-user-ca-keys.pem /etc/ssh/trusted-user-ca-keys.pem",
      "  sudo chmod 644 /etc/ssh/trusted-user-ca-keys.pem",
      "  sudo grep -q '^TrustedUserCAKeys' /etc/ssh/sshd_config || echo 'TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem' | sudo tee -a /etc/ssh/sshd_config",
      "  sudo systemctl restart sshd",
      "else",
      "  echo 'No Vault SSH CA key provided, skipping...'",
      "  rm -f /tmp/trusted-user-ca-keys.pem",
      "fi"
    ]
  }

  # Cleanup
  provisioner "shell" {
    inline = [
      "echo 'Cleaning up...'",
      "sudo dnf clean all",
      "rm -f /tmp/aap-setup-bundle.tar.gz",
      "echo 'AAP Controller image build complete!'"
    ]
  }
}
