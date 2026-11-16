# These four values become repository variables in GitHub.

output "aws_region" {
  description = "Value for the AWS_REGION repository variable."
  value       = var.aws_region
}

output "state_bucket" {
  description = "Value for the STATE_BUCKET repository variable."
  value       = aws_s3_bucket.state.id
}

output "plan_role_arn" {
  description = "Value for the AWS_PLAN_ROLE_ARN repository variable."
  value       = aws_iam_role.plan.arn
}

output "apply_role_arn" {
  description = "Value for the AWS_APPLY_ROLE_ARN repository variable."
  value       = aws_iam_role.apply.arn
}
