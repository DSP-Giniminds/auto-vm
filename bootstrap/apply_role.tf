# Apply role: only jobs running in the protected GitHub Environment can assume
# it. A job that uses an environment gets an environment-based `sub`, so the
# trust keys on the environment name. Restrict that environment's deployment
# branches to main in GitHub.

data "aws_iam_policy_document" "apply_trust" {
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
      values   = ["${local.github_sub}:environment:${var.apply_environment}"]
    }
  }
}

data "aws_iam_policy_document" "apply" {
  # Everything the plan role can read, plus the write permissions below.
  source_policy_documents = [data.aws_iam_policy_document.read_only.json]

  # The instance must be an allowed type and tagged ManagedBy at creation.
  statement {
    sid       = "RunInstance"
    actions   = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:InstanceType"
      values   = var.allowed_instance_types
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/ManagedBy"
      values   = ["terraform-request-pipeline"]
    }
  }

  # The other resources RunInstances uses: existing network, new volume and ENI, the AMI.
  statement {
    sid     = "RunInstanceSupportingResources"
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:volume/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:network-interface/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:subnet/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:security-group/*",
      "arn:aws:ec2:${var.aws_region}::image/*",
    ]
  }

  statement {
    sid     = "TagOnCreate"
    actions = ["ec2:CreateTags"]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:volume/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:network-interface/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values   = ["RunInstances"]
    }
  }

  # Later changes and destroy, only on resources this pipeline created.
  statement {
    sid = "ManageOwnResources"
    actions = [
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:TerminateInstances",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "ec2:ModifyInstanceAttribute",
      "ec2:ModifyInstanceMetadataOptions",
      "ec2:ModifyVolume",
    ]
    resources = [
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:instance/*",
      "arn:aws:ec2:${var.aws_region}:${local.account_id}:volume/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/ManagedBy"
      values   = ["terraform-request-pipeline"]
    }
  }

  # Encrypted root volumes use the account's default aws/ebs key.
  statement {
    sid = "EbsEncryption"
    actions = [
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:Decrypt",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:ReEncrypt*",
    ]
    resources = ["arn:aws:kms:${var.aws_region}:${local.account_id}:key/*"]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["ec2.${var.aws_region}.amazonaws.com"]
    }
  }

  # Put and delete cover the state object and its .tflock lock object.
  statement {
    sid       = "StateWrite"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/${local.state_prefix}/*"]
  }
}

resource "aws_iam_role" "apply" {
  name               = "vm-governance-apply"
  assume_role_policy = data.aws_iam_policy_document.apply_trust.json
}

resource "aws_iam_role_policy" "apply" {
  name   = "apply"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply.json
}
