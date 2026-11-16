module "vm" {
  source = "../../modules/aws-ec2-vm"

  request_id         = var.request_id
  vm_name            = var.vm_name
  requester          = var.requester
  justification      = var.justification
  environment        = var.environment
  instance_type      = var.instance_type
  os                 = var.os
  root_volume_gb     = var.root_volume_gb
  subnet_id          = var.subnet_id
  security_group_ids = var.security_group_ids
  assign_public_ip   = var.assign_public_ip

  # Pointer from the VM back to the approved change in Git.
  extra_tags = {
    SourceRepo   = var.source_repo
    SourcePR     = var.source_pr
    SourceCommit = var.source_commit
  }
}
