# Read by the pipeline (terraform output -json) for the result comment on the PR.

output "instance_id" {
  description = "EC2 instance ID."
  value       = module.vm.instance_id
}

output "private_ip" {
  description = "Private IP address."
  value       = module.vm.private_ip
}

output "public_ip" {
  description = "Public IP address (empty unless requested)."
  value       = module.vm.public_ip
}

output "ami_id" {
  description = "AMI the instance was created from."
  value       = module.vm.ami_id
}
