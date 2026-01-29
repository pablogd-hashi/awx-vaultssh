# -----------------------------------------------------------------------------
# Output Values
# -----------------------------------------------------------------------------

output "vm_name" {
  description = "Name of the created VM"
  value       = google_compute_instance.vm.name
}

output "vm_external_ip" {
  description = "External IP address of the VM"
  value       = google_compute_instance.vm.network_interface[0].access_config[0].nat_ip
}

output "vm_internal_ip" {
  description = "Internal IP address of the VM"
  value       = google_compute_instance.vm.network_interface[0].network_ip
}

output "vm_zone" {
  description = "Zone where the VM is deployed"
  value       = google_compute_instance.vm.zone
}

output "streamlit_url" {
  description = "URL to access the Streamlit demo application"
  value       = "http://${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}:${var.streamlit_port}"
}

output "ssh_command" {
  description = "SSH command to connect to the VM (requires Vault-signed certificate)"
  value       = "ssh -i /path/to/private_key -i /path/to/signed_cert.pub ${var.ssh_user}@${google_compute_instance.vm.network_interface[0].access_config[0].nat_ip}"
}

output "gcloud_ssh_command" {
  description = "GCloud SSH command (uses Google's SSH keys, not Vault)"
  value       = "gcloud compute ssh ${var.ssh_user}@${google_compute_instance.vm.name} --zone=${var.zone}"
}

output "network_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.main.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.main.name
}
