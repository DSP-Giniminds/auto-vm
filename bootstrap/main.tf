# One-time bootstrap, applied locally by a human. It creates only what the
# pipeline needs to run: the state bucket, the GitHub OIDC trust and two roles.

data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "vm-governance-tfstate-${local.account_id}"

  # Request states live at <state_prefix>/<request_id>/terraform.tfstate.
  state_prefix = "aws-ec2-vm"

  github_sub = "repo:${var.github_repo}"

  # The only SSM parameters the module reads (latest Amazon Linux AMIs).
  ami_parameter_arn = "arn:aws:ssm:${var.aws_region}::parameter/aws/service/ami-amazon-linux-latest/*"
}
