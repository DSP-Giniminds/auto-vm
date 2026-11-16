terraform {
  required_version = "~> 1.17.0"

  # Partial configuration on purpose: bucket, region and the per-request key are
  # passed at `terraform init` (see .github/actions/terraform-init), so every
  # request gets its own state file and lock.
  backend "s3" {}

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
