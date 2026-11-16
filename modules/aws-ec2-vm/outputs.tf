output "instance_id" {
  description = "EC2 instance ID."
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "Private IP address."
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "Public IP, empty unless one was requested."
  value       = aws_instance.this.public_ip
}

output "ami_id" {
  description = "AMI the instance was built from."
  value       = aws_instance.this.ami
}
