# Plan role: read-only. Used by pull_request runs and by the apply workflow's
# plan job on main (which runs before the approval gate).

data "aws_iam_policy_document" "plan_trust" {
  #checkov:skip=CKV_AWS_356: ec2:Describe* and the EBS default-key reads do not support resource-level permissions, so "*" is the only valid value
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["${local.github_sub}:pull_request", "${local.github_sub}:ref:refs/heads/main"]
    }
  }
}

# Also reused by the apply role. PR plans run with -lock=false, so no state write is needed.
data "aws_iam_policy_document" "read_only" {
  statement {
    sid       = "Ec2Describe"
    actions   = ["ec2:Describe*", "ec2:GetEbsEncryptionByDefault", "ec2:GetEbsDefaultKmsKeyId"]
    resources = ["*"]
  }

  statement {
    sid       = "ReadAmiParameter"
    actions   = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = [local.ami_parameter_arn]
  }

  statement {
    sid       = "StateList"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["${local.state_prefix}/*"]
    }
  }

  statement {
    sid       = "StateRead"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_prefix}/*"]
  }
}

resource "aws_iam_role" "plan" {
  name               = "vm-governance-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
}

resource "aws_iam_role_policy" "plan" {
  name   = "plan"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.read_only.json
}
