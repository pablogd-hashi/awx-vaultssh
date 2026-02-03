# -----------------------------------------------------------------------------
# Outputs - VM Module
# -----------------------------------------------------------------------------

output "instance_ids" {
  description = "IDs of created EC2 instances"
  value       = aws_instance.vm[*].id
}

output "private_ips" {
  description = "Private IP addresses of instances"
  value       = aws_instance.vm[*].private_ip
}

output "public_ips" {
  description = "Public IP addresses of instances (if assigned)"
  value       = aws_instance.vm[*].public_ip
}

output "security_group_id" {
  description = "ID of the VM security group"
  value       = aws_security_group.vm.id
}

output "ami_id" {
  description = "AMI ID used for instances"
  value       = local.ami_id
}

output "ssh_user" {
  description = "SSH username for connecting to instances"
  value       = var.ssh_user
}

output "inventory" {
  description = "Ansible inventory format for instances"
  value = {
    for idx, instance in aws_instance.vm : instance.tags["Name"] => {
      ansible_host = instance.public_ip != "" ? instance.public_ip : instance.private_ip
      ansible_user = var.ssh_user
      private_ip   = instance.private_ip
      public_ip    = instance.public_ip
      instance_id  = instance.id
    }
  }
}
