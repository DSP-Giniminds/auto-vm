# Rules live here (not only in CI) so they hold no matter who calls the module.

variable "request_id" {
  description = "Unique request ID (later a ServiceNow ticket number). Links the VM to its request."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]{2,39}$", var.request_id))
    error_message = "request_id must be 3-40 characters: letters, digits and hyphens, starting with a letter or digit."
  }
}

variable "vm_name" {
  description = "Server name. Becomes the Name tag."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,62}$", var.vm_name))
    error_message = "vm_name must be 3-63 characters, lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "requester" {
  description = "Who asked for the VM (GitHub username)."
  type        = string

  validation {
    condition     = length(trimspace(var.requester)) > 0
    error_message = "requester must not be empty."
  }
}

variable "justification" {
  description = "Business reason for the VM. Required for the audit trail."
  type        = string

  validation {
    condition     = length(trimspace(var.justification)) >= 10
    error_message = "justification is required (at least 10 characters)."
  }
}

variable "environment" {
  description = "Target environment."
  type        = string

  validation {
    condition     = contains(["dev", "test", "uat", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, uat, prod."
  }
}

variable "allowed_instance_types" {
  description = "Instance types requesters may pick. Free-tier types by default; add larger ones (e.g. t3.medium) here via a reviewed change to this module."
  type        = list(string)
  default     = ["t3.micro", "t2.micro"]
}

variable "instance_type" {
  description = "EC2 instance type; must be in allowed_instance_types."
  type        = string

  validation {
    condition     = contains(var.allowed_instance_types, var.instance_type)
    error_message = "instance_type is not in the allowlist (allowed_instance_types)."
  }
}

variable "os_ssm_parameters" {
  description = "Allowed OS choices, each mapped to the public SSM parameter holding its latest AMI ID. x86_64 only, so pick x86_64 instance types."
  type        = map(string)
  default = {
    "amazon-linux-2023" = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  }
}

variable "os" {
  description = "OS key from os_ssm_parameters."
  type        = string

  validation {
    condition     = contains(keys(var.os_ssm_parameters), var.os)
    error_message = "os is not one of the allowed options (keys of os_ssm_parameters)."
  }
}

variable "root_volume_gb" {
  description = "Root volume size in GB (gp3, always encrypted). Free tier EBS allowance is 30 GB in total."
  type        = number

  validation {
    condition     = var.root_volume_gb >= 8 && var.root_volume_gb <= 200 && floor(var.root_volume_gb) == var.root_volume_gb
    error_message = "root_volume_gb must be a whole number between 8 and 200."
  }
}

variable "subnet_id" {
  description = "Existing subnet. Passed in, not created."
  type        = string

  validation {
    condition     = can(regex("^subnet-[0-9a-f]{8,17}$", var.subnet_id))
    error_message = "subnet_id must look like subnet-0123456789abcdef0."
  }
}

variable "security_group_ids" {
  description = "Existing security groups. Passed in, not created."
  type        = list(string)

  validation {
    condition     = length(var.security_group_ids) > 0 && alltrue([for sg in var.security_group_ids : can(regex("^sg-[0-9a-f]{8,17}$", sg))])
    error_message = "security_group_ids needs at least one ID, each like sg-0123456789abcdef0."
  }
}

variable "assign_public_ip" {
  description = "Give the instance a public IP. Off unless explicitly requested."
  type        = bool
  default     = false
}

variable "extra_tags" {
  description = "Additional tags, e.g. a pointer to the PR/commit that approved this request."
  type        = map(string)
  default     = {}
}
