locals {
  # extra_tags first so the core tags below can never be overridden by a caller.
  tags = merge(var.extra_tags, {
    Name        = var.vm_name
    RequestID   = var.request_id
    Requester   = var.requester
    Environment = var.environment
    # The apply role's IAM conditions key on this exact value. Don't change one without the other.
    ManagedBy = "terraform-request-pipeline"
  })
}

# Resolved at creation time through the public SSM parameter (no hard-coded AMI ID).
data "aws_ssm_parameter" "ami" {
  name = var.os_ssm_parameters[var.os]
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.ami.insecure_value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  associate_public_ip_address = var.assign_public_ip

  # IMDSv2 only: blocks the common SSRF-to-credentials path.
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_gb
    encrypted             = true
    delete_on_termination = true
    tags                  = local.tags
  }

  # Root volume tags are set inside root_block_device (they conflict with volume_tags).
  tags = local.tags

  lifecycle {
    # "Latest" AMI moves over time. Without this, any later run would want to
    # REPLACE the VM just because AWS published a new image, and the same request
    # would not give the same VM. The AMI chosen at creation stays fixed; to roll
    # to a newer image, change the request deliberately (for example via a taint or
    # a new request).
    ignore_changes = [ami]
  }
}
