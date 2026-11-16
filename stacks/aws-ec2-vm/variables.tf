# Request fields: these mirror the request file. The module validates the values.

variable "request_id" {
  description = "Unique request ID."
  type        = string
}

variable "target" {
  description = "Target platform of the request. Selects this stack; not used by the module."
  type        = string
}

variable "vm_name" {
  description = "Server name."
  type        = string
}

variable "requester" {
  description = "GitHub username of the requester."
  type        = string
}

variable "justification" {
  description = "Business reason for the VM."
  type        = string
}

variable "environment" {
  description = "Target environment."
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type."
  type        = string
}

variable "os" {
  description = "Operating system key."
  type        = string
}

variable "root_volume_gb" {
  description = "Root volume size in GB."
  type        = number
}

variable "subnet_id" {
  description = "Existing subnet ID."
  type        = string
}

variable "security_group_ids" {
  description = "Existing security group IDs."
  type        = list(string)
}

variable "assign_public_ip" {
  description = "Give the instance a public IP."
  type        = bool
  default     = false
}

# Supplied by the pipeline, not by the requester.

variable "aws_region" {
  description = "Region to create the VM in."
  type        = string
}

variable "source_repo" {
  description = "Repository that holds the approved request. Tagged on the VM."
  type        = string
  default     = "local"
}

variable "source_pr" {
  description = "Pull request that carried the request. Tagged on the VM."
  type        = string
  default     = "n/a"
}

variable "source_commit" {
  description = "Commit the VM was applied from. Tagged on the VM."
  type        = string
  default     = "local"
}
