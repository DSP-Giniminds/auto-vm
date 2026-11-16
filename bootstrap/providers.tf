provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "vm-governance-demo"
      ManagedBy = "terraform-bootstrap"
    }
  }
}
