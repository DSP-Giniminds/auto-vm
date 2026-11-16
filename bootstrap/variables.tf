variable "aws_region" {
  description = "Region for the state bucket and for the EC2 instances the pipeline creates."
  type        = string
}

variable "github_repo" {
  description = "GitHub repository allowed to assume the roles, as <org-or-user>/<repo>."
  type        = string
}

variable "apply_environment" {
  description = "GitHub Environment whose jobs may assume the apply role. Must match the workflows."
  type        = string
  default     = "aws-apply"
}

variable "allowed_instance_types" {
  description = "Instance types the apply role may launch (IAM backstop for the module allowlist)."
  type        = list(string)
  default     = ["t3.micro", "t2.micro"]
}
