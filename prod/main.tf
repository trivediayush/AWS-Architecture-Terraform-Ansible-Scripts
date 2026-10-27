# Production environment: S3, RDS Multi-AZ, ECS capacity + service, ALB, alarms.
# Depends on ../shared (subnets, SGs, IAM roles, ECR, alarm topic) only.

data "terraform_remote_state" "shared" {
  backend = "local"
  config  = { path = "${path.module}/../shared/terraform.tfstate" }
}

locals {
  vpc_id                = data.terraform_remote_state.shared.outputs.vpc_id
  public_subnet_ids     = data.terraform_remote_state.shared.outputs.public_subnet_ids
  private_subnet_ids    = data.terraform_remote_state.shared.outputs.app_subnet_ids
  database_subnet_ids   = data.terraform_remote_state.shared.outputs.database_subnet_ids
  alb_security_group_id = data.terraform_remote_state.shared.outputs.alb_security_group_id
  ecs_security_group_id = data.terraform_remote_state.shared.outputs.ecs_security_group_id
  rds_security_group_id = data.terraform_remote_state.shared.outputs.rds_security_group_id

  ecs_instance_profile_name   = data.terraform_remote_state.shared.outputs.ecs_instance_profile_name
  task_execution_role_arn     = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_arn
  task_execution_role_name    = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_name
  task_role_arn               = data.terraform_remote_state.shared.outputs.ecs_task_role_arn
  task_role_name              = data.terraform_remote_state.shared.outputs.ecs_task_role_name
  ecs_instance_role_name      = data.terraform_remote_state.shared.outputs.ecs_instance_profile_name
  alarm_topic_arn             = data.terraform_remote_state.shared.outputs.alarm_topic_arn
  alarm_actions               = local.alarm_topic_arn != "" ? [local.alarm_topic_arn] : []
}

data "aws_caller_identity" "this" {}
data "aws_elb_service_account" "this" {}
data "aws_vpc" "selected" { id = local.vpc_id }

# ---------- production s3 ----------

resource "aws_s3_bucket" "production" {
  bucket = var.bucket_name
  tags   = { Name = var.bucket_name, Environment = "production" }
}

resource "aws_s3_bucket_public_access_block" "production" {
  bucket                  = aws_s3_bucket.production.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "production" {
  bucket = aws_s3_bucket.production.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_versioning" "production" {
  bucket = aws_s3_bucket.production.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_lifecycle_configuration" "production" {
  bucket = aws_s3_bucket.production.id
  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}
    noncurrent_version_expiration { noncurrent_days = 90 }
    abort_incomplete_multipart_upload { days_after_initiation = 7 }
  }
}

# ---------- rds ----------

resource "aws_db_subnet_group" "this" {
  name       = "${var.db_identifier}-subnets"
  subnet_ids = local.database_subnet_ids
  tags       = { Name = "${var.db_identifier}-subnets" }
}

resource "aws_db_instance" "this" {
  identifier                      = var.db_identifier
  engine                          = "postgres"
  engine_version                  = var.engine_version
  instance_class                  = var.instance_class
  allocated_storage               = var.allocated_storage_gb
  max_allocated_storage           = var.max_allocated_storage_gb
  storage_type                    = "gp3"
  storage_encrypted               = true
  multi_az                        = true
  performance_insights_enabled    = true
  apply_immediately               = var.apply_immediately
  db_name                         = var.db_name
  username                        = var.master_username
  manage_master_user_password     = true
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [local.rds_security_group_id]
  publicly_accessible             = false
  backup_retention_period         = var.backup_retention_days
  auto_minor_version_upgrade      = true
  deletion_protection             = var.deletion_protection
  skip_final_snapshot             = false
  final_snapshot_identifier       = var.final_snapshot_identifier
  copy_tags_to_snapshot           = true
  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]
  tags                            = { Name = var.db_identifier, Environment = "production" }
}

# ---------- ecs capacity ----------

resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = { Environment = "production" }
}

resource "aws_launch_template" "this" {
  name_prefix            = "${var.project_name}-ecs-"
  image_id               = var.ecs_ami_id
  instance_type          = var.ecs_instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [local.ecs_security_group_id]
  iam_instance_profile { name = local.ecs_instance_profile_name }
  update_default_version = true
  # Ubuntu has no baked-in ECS agent — run it as a container (documented path
  # for non-Amazon-Linux hosts). If switching back to an ECS-optimized AL2023
  # AMI, the docker run is still harmless but the /etc/ecs/ecs.config lines
  # below cover that case too.
  user_data = base64encode(<<-EOT
    #!/bin/bash
    set -euo pipefail
    if ! apt-get update -y; then
      # AL2023 path — baked-in agent just needs the cluster name.
      echo ECS_CLUSTER=${aws_ecs_cluster.this.name} >> /etc/ecs/ecs.config
      echo ECS_ENABLE_CONTAINER_METADATA=true >> /etc/ecs/ecs.config
      systemctl enable --now ecs
      exit 0
    fi
    apt-get install -y docker.io
    systemctl enable --now docker
    docker run --name ecs-agent --detach=true --restart=on-failure:10 \
      --net=host \
      --volume=/var/run/docker.sock:/var/run/docker.sock \
      --volume=/var/log/ecs:/log --volume=/var/lib/ecs:/data \
      --env=ECS_CLUSTER=${aws_ecs_cluster.this.name} \
      --env=ECS_ENABLE_CONTAINER_METADATA=true \
      amazon/amazon-ecs-agent:latest
    EOT
  )
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = var.ecs_root_volume_size_gb
      encrypted             = true
      delete_on_termination = true
    }
  }
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${var.project_name}-production-ecs-node", Environment = "production" }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = "${var.project_name}-production-ecs-asg"
  min_size                  = var.ecs_min_size
  max_size                  = var.ecs_max_size
  desired_capacity          = var.ecs_desired_capacity
  vpc_zone_identifier       = local.private_subnet_ids
  health_check_type         = "EC2"
  health_check_grace_period = 300
  # Roll nodes when the launch template version changes (one at a time keeps
  # multi-AZ capacity up).
  instance_refresh {
    strategy = "Rolling"
    preferences { min_healthy_percentage = 50 }
  }
  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.project_name}-production-ecs-node"
    propagate_at_launch = true
  }
  tag {
    key                 = "Environment"
    value               = "production"
    propagate_at_launch = true
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.project_name}-production-ec2-capacity"
  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn
    managed_scaling {
      status          = "DISABLED"
      target_capacity = 100
    }
    managed_termination_protection = "DISABLED"
  }
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name       = aws_ecs_cluster.this.name
  capacity_providers = [aws_ecs_capacity_provider.this.name]
  default_capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.this.name
    weight            = 1
  }
}

# ---------- alb ----------

resource "aws_lb" "this" {
  name                       = var.load_balancer_name
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [local.alb_security_group_id]
  subnets                    = local.public_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_alb_deletion_protection
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

# HTTP-only mode: no certificate yet, so forward 80 directly. Removed
# automatically once certificate_arn is set (http_redirect takes over).
# Insecure — testing only; supply a cert before real traffic.
resource "aws_lb_listener" "http_forward" {
  count             = var.certificate_arn == "" ? 1 : 0
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
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
    filter {}
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
        Principal = { AWS = "arn:aws:iam::${data.aws_elb_service_account.this.id}:root" }
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

# ---------- ecs service ----------

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/${var.project_name}/production"
  retention_in_days = var.log_retention_days
  tags              = { Environment = "production" }
}

# Production ECS service + task definition. Confirm image/port/CPU/memory/
# health endpoint/secrets before apply — targets go unhealthy on placeholders.
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-production-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.task_role_arn
  container_definitions = jsonencode([
    {
      name      = "app"
      image     = var.image_uri
      essential = true
      portMappings = [
        { containerPort = var.app_port, hostPort = var.app_port, protocol = "tcp" }
      ]
      environment = [for k, v in var.container_environment : { name = k, value = v }]
      secrets     = [for k, v in var.container_secrets : { name = k, valueFrom = v }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-production-app"
  cluster         = aws_ecs_cluster.this.name
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [local.ecs_security_group_id]
  }
  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.app_port
  }
  # A listener must exist first — without it the TG has no associated LB and
  # CreateService fails with InvalidParameterException.
  depends_on = [aws_lb_listener.https, aws_lb_listener.http_forward, aws_lb_listener.http_redirect]
  health_check_grace_period_seconds = 60
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  tags = { Environment = "production" }
}

# ---------- task role scoped policies ----------

# Prod-bucket object access for the app container.
resource "aws_iam_role_policy" "ecs_task_s3" {
  name = "${var.project_name}-task-s3"
  role = local.task_role_name
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.production.arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.production.arn}/*" }
  ] })
}

# Lets the execution role resolve Secrets Manager references in the task def.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = length(var.task_secret_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-exec-secrets"
  role  = local.task_execution_role_name
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.task_secret_arns }
  ] })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  count = length(var.task_secret_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-task-secrets"
  role  = local.task_role_name
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.task_secret_arns }
  ] })
}

# ---------- alarms ----------

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
}

resource "aws_cloudwatch_metric_alarm" "rds_free_storage" {
  alarm_name          = "${var.project_name}-rds-low-storage"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 21474836480 # 20 GiB
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  dimensions          = { DBInstanceIdentifier = aws_db_instance.this.identifier }
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  dimensions = {
    LoadBalancer = aws_lb.this.arn_suffix
    TargetGroup  = aws_lb_target_group.app.arn_suffix
  }
}

resource "aws_cloudwatch_metric_alarm" "ecs_service_cpu" {
  alarm_name          = "${var.project_name}-ecs-service-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  treat_missing_data  = "missing"
  alarm_actions       = local.alarm_actions
  dimensions = {
    ClusterName = aws_ecs_cluster.this.name
    ServiceName = aws_ecs_service.app.name
  }
}
