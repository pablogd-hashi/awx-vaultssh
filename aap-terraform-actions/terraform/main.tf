# -----------------------------------------------------------------------------
# Vault SSH CA Public Key
# Fetch the CA public key to install on the VM for certificate validation
# -----------------------------------------------------------------------------

data "vault_generic_secret" "ssh_ca_public_key" {
  path = "${var.vault_ssh_path}/config/ca"
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

resource "google_compute_network" "main" {
  name                    = var.network_name
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.main.id
}

# -----------------------------------------------------------------------------
# Firewall Rules
# -----------------------------------------------------------------------------

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = var.allowed_ssh_ranges
  target_tags   = ["ssh-enabled"]
}

resource "google_compute_firewall" "allow_streamlit" {
  name    = "${var.network_name}-allow-streamlit"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = [tostring(var.streamlit_port)]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["streamlit"]
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  source_ranges = [var.subnet_cidr]
}

# -----------------------------------------------------------------------------
# Compute Instance
# -----------------------------------------------------------------------------

resource "google_compute_instance" "vm" {
  name         = var.vm_name
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["ssh-enabled", "streamlit"]

  boot_disk {
    initialize_params {
      image = var.os_image
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.main.id

    access_config {
      # Ephemeral public IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    set -e

    # Create the SSH user if it doesn't exist
    if ! id "${var.ssh_user}" &>/dev/null; then
      useradd -m -s /bin/bash ${var.ssh_user}
      echo "${var.ssh_user} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers.d/${var.ssh_user}
    fi

    # Install Vault CA public key for SSH certificate validation
    cat > /etc/ssh/trusted-user-ca-keys.pem << 'CAKEY'
    ${data.vault_generic_secret.ssh_ca_public_key.data["public_key"]}
    CAKEY

    # Configure SSH daemon to trust Vault CA
    if ! grep -q "TrustedUserCAKeys" /etc/ssh/sshd_config; then
      echo "TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem" >> /etc/ssh/sshd_config
    fi

    # Restart SSH daemon
    systemctl restart sshd

    # Install Python for Ansible
    if command -v dnf &> /dev/null; then
      dnf install -y python3 python3-pip
    elif command -v apt-get &> /dev/null; then
      apt-get update && apt-get install -y python3 python3-pip
    fi

    echo "VM initialization complete - ready for AAP configuration"
  EOF

  service_account {
    scopes = ["cloud-platform"]
  }

  # Ensure the VM is fully provisioned before triggering AAP
  depends_on = [
    google_compute_firewall.allow_ssh,
    google_compute_firewall.allow_streamlit,
  ]
}

# -----------------------------------------------------------------------------
# AAP Job Trigger
# This terraform_data resource serves as the trigger point for the AAP Action
# -----------------------------------------------------------------------------

resource "terraform_data" "aap_trigger" {
  input = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip

  depends_on = [
    google_compute_instance.vm,
    google_compute_firewall.allow_ssh,
  ]

  lifecycle {
    action_trigger {
      events  = [after_create, after_update]
      actions = [action.aap_job_launch.configure_vm]
    }
  }
}
