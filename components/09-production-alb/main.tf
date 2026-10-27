# shortcut: reads sibling components' local state; switch backend/config to s3
# after remote-state migration.
data "terraform_remote_state" "network" {
  count   = var.vpc_id == "" || length(var.public_subnet_ids) == 0 ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../00-network/terraform.tfstate" }
}
data "terraform_remote_state" "security" {
  count   = var.alb_security_group_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../01-security-groups/terraform.tfstate" }
}

locals {
  vpc_id                = var.vpc_id != "" ? var.vpc_id : data.terraform_remote_state.network[0].outputs.vpc_id
  public_subnet_ids     = length(var.public_subnet_ids) > 0 ? var.public_subnet_ids : data.terraform_remote_state.network[0].outputs.public_subnet_ids
  alb_security_group_id = var.alb_security_group_id != "" ? var.alb_security_group_id : data.terraform_remote_state.security[0].outputs.alb_security_group_id
}

data "aws_caller_identity" "this" {}
data "aws_elb_service_account" "this" {}

resource "aws_lb" "this" {
  name                       = var.load_balancer_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [local.alb_security_group_id]
  subnets                    = local.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection
  dynamic "access_logs" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].id
      enabled = true
    }
  }
  tags = { Environment = "production" }
}

resource "aws_lb_target_group" "app" {
  name        = "${var.project_name}-prod-app"
  port        = var.target_port
  protocol    = "HTTP"
  target_type = var.target_type
  vpc_id      = local.vpc_id
  health_check {
    enabled             = true
    path                = var.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
  tags = { Environment = "production" }
}

data "aws_vpc" "selected" { id = local.vpc_id }

resource "aws_lb_listener" "https" {
  count             = var.certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_lb_listener" "http_redirect" {
  count             = var.certificate_arn == "" ? 0 : 1
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ALB access logs bucket (SSE-S3 only; KMS is not supported for ALB log delivery).
resource "aws_s3_bucket" "alb_logs" {
  count         = var.enable_access_logs ? 1 : 0
  bucket        = var.access_logs_bucket_name
  force_destroy = var.access_logs_force_destroy
  tags          = { Environment = "production", Purpose = "alb-access-logs" }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  count                   = var.enable_access_logs ? 1 : 0
  bucket                  = aws_s3_bucket.alb_logs[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    expiration { days = var.access_logs_retention_days }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  count  = var.enable_access_logs ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = data.aws_elb_service_account.this.arn }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.this.account_id}/*"
      },
      {
        Effect    = "Allow"
        Principal = { Service = "logdelivery.elasticloadbalancing.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.alb_logs[0].arn}/AWSLogs/${data.aws_caller_identity.this.account_id}/*"
      }
    ]
  })
}
