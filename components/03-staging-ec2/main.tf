# shortcut: reads sibling components' local state; switch backend/config to s3
# after remote-state migration.
data "terraform_remote_state" "network" {
  count   = var.subnet_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../00-network/terraform.tfstate" }
}
data "terraform_remote_state" "security" {
  count   = var.security_group_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../01-security-groups/terraform.tfstate" }
}
data "terraform_remote_state" "iam" {
  count   = var.instance_profile_name == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../02-iam/terraform.tfstate" }
}

locals {
  # Staging goes in the first public subnet (SSH via public IP + IGW).
  subnet_id             = var.subnet_id != "" ? var.subnet_id : data.terraform_remote_state.network[0].outputs.public_subnet_ids[0]
  security_group_id     = var.security_group_id != "" ? var.security_group_id : data.terraform_remote_state.security[0].outputs.staging_security_group_id
  instance_profile_name = var.instance_profile_name != "" ? var.instance_profile_name : data.terraform_remote_state.iam[0].outputs.staging_instance_profile_name
}

# Latest Amazon Linux 2023 ARM64 AMI via EC2 API (no SSM).
data "aws_ami" "al2023_arm64" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-arm64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "staging" {
  ami                         = var.ami_id_override != "" ? var.ami_id_override : data.aws_ami.al2023_arm64.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_name
  subnet_id                   = local.subnet_id
  vpc_security_group_ids      = [local.security_group_id]
  iam_instance_profile        = local.instance_profile_name
  associate_public_ip_address = var.associate_public_ip_address
  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size_gb
    encrypted             = true
    delete_on_termination = true
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tags = { Name = "${var.project_name}-staging-ec2", Environment = "staging", Role = "staging" }
  lifecycle { ignore_changes = [ami] }
}
