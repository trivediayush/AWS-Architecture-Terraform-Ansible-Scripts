# Staging environment: one public EC2, staging S3 bucket, log group, status alarm.
# Depends on ../shared (subnets, SG, instance profile, alarm topic) only.

data "terraform_remote_state" "shared" {
  backend = "local"
  config  = { path = "${path.module}/../shared/terraform.tfstate" }
}

locals {
  # Staging goes in the first public subnet (SSH via public IP + IGW).
  subnet_id             = var.subnet_id != "" ? var.subnet_id : data.terraform_remote_state.shared.outputs.public_subnet_ids[0]
  security_group_id     = data.terraform_remote_state.shared.outputs.staging_security_group_id
  instance_profile_name = data.terraform_remote_state.shared.outputs.staging_instance_profile_name
  alarm_topic_arn       = data.terraform_remote_state.shared.outputs.alarm_topic_arn
  alarm_actions         = local.alarm_topic_arn != "" ? [local.alarm_topic_arn] : []
}

# Latest Amazon Linux 2023 x86_64 AMI via EC2 API (no SSM).
# x86 because Graviton t4g capacity is unreliable in ap-south-1; flip filter to
# *-arm64 and instance_type to t4g.* if that changes.
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "staging" {
  ami                         = var.ami_id_override != "" ? var.ami_id_override : data.aws_ami.al2023.id
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

# ---------- s3 ----------

resource "aws_s3_bucket" "staging" {
  bucket = var.bucket_name
  tags   = { Name = var.bucket_name, Environment = "staging" }
}

resource "aws_s3_bucket_public_access_block" "staging" {
  bucket                  = aws_s3_bucket.staging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "staging" {
  bucket = aws_s3_bucket.staging.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "staging" {
  bucket = aws_s3_bucket.staging.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# Staging-app S3 access, scoped to this bucket. Attached here (not in shared) so
# shared never depends back on an env root.
resource "aws_iam_role_policy" "staging_s3" {
  name = "${var.project_name}-staging-s3"
  role = data.terraform_remote_state.shared.outputs.staging_role_name
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.staging.arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.staging.arn}/*" }
  ] })
}

# ---------- observability ----------

resource "aws_cloudwatch_log_group" "staging" {
  name              = "/aws/ec2/${var.project_name}/staging"
  retention_in_days = var.log_retention_days
  tags              = { Environment = "staging" }
}

resource "aws_cloudwatch_metric_alarm" "staging_status_check" {
  alarm_name          = "${var.project_name}-staging-ec2-status-check"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  threshold           = 1
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  dimensions          = { InstanceId = aws_instance.staging.id }
}
