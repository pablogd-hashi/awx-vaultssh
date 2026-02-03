# -----------------------------------------------------------------------------
# Outputs - AAP Controller
#
# These outputs are used as inputs to the infra module.
# -----------------------------------------------------------------------------

output "aap_url" {
  description = "AAP Controller URL"
  value       = "https://${aws_instance.aap.public_ip}"
}

output "aap_host" {
  description = "AAP Controller hostname (for Terraform provider)"
  value       = "https://${aws_instance.aap.public_ip}"
}

output "aap_public_ip" {
  description = "AAP Controller public IP address"
  value       = aws_instance.aap.public_ip
}

output "aap_private_ip" {
  description = "AAP Controller private IP address"
  value       = aws_instance.aap.private_ip
}

output "aap_instance_id" {
  description = "AAP Controller EC2 instance ID"
  value       = aws_instance.aap.id
}

output "aap_private_key" {
  description = "SSH private key for AAP Controller"
  value       = tls_private_key.aap.private_key_pem
  sensitive   = true
}

output "aap_public_key" {
  description = "SSH public key for AAP Controller"
  value       = tls_private_key.aap.public_key_openssh
}

output "aap_username" {
  description = "Default AAP admin username"
  value       = "admin"
}

output "aap_password" {
  description = "Default AAP admin password"
  value       = "Hashi123!"
  sensitive   = true
}

# Network outputs for peering/connectivity
output "vpc_id" {
  description = "VPC ID where AAP is deployed"
  value       = aws_vpc.aap.id
}

output "subnet_id" {
  description = "Subnet ID where AAP is deployed"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security group ID for AAP"
  value       = aws_security_group.aap.id
}

output "aws_region" {
  description = "AWS region where AAP is deployed"
  value       = var.aws_region
}
