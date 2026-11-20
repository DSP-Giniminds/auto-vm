# Terraform state. Locking uses S3 native lock files (use_lockfile), so no
# DynamoDB table is needed.

resource "aws_s3_bucket" "state" {
  # Accepted risks for the PoC state bucket (it only holds Terraform state):
  #checkov:skip=CKV_AWS_18: access logging needs a second log bucket; S3 data events can be added through CloudTrail if wanted
  #checkov:skip=CKV_AWS_144: single-region PoC, cross-region replication is not needed
  #checkov:skip=CKV_AWS_145: SSE-S3 (AES256) is accepted; a customer-managed KMS key adds cost and a key policy to maintain
  #checkov:skip=CKV2_AWS_61: old state versions are kept on purpose, no lifecycle rule (see bootstrap notes)
  #checkov:skip=CKV2_AWS_62: no consumer of bucket events exists, notifications are not needed
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.state]
}
