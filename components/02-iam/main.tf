data "aws_partition" "current" {}

# Staging EC2: SSH/PEM access only, CloudWatch agent for logs/metrics.
resource "aws_iam_role" "staging_ec2" {
  name               = "${var.project_name}-staging-ec2-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy_attachment" "staging_cw" {
  role       = aws_iam_role.staging_ec2.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "staging" {
  name = "${var.project_name}-staging-profile"
  role = aws_iam_role.staging_ec2.name
}

# Staging app S3 access, scoped to the staging bucket only.
resource "aws_iam_role_policy" "staging_s3" {
  count = var.staging_bucket_arn == "" ? 0 : 1
  name  = "${var.project_name}-staging-s3"
  role  = aws_iam_role.staging_ec2.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = var.staging_bucket_arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${var.staging_bucket_arn}/*" }
  ] })
}

# ECS container-instance role (registers nodes with the cluster, agent telemetry).
resource "aws_iam_role" "ecs_instance" {
  name               = "${var.project_name}-ecs-instance-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.project_name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name
}

# Execution role: ECS agent uses it to pull images and inject secrets.
resource "aws_iam_role" "ecs_task_execution" {
  name               = "${var.project_name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Lets the execution role resolve Secrets Manager references in the task def.
resource "aws_iam_role_policy" "ecs_task_execution_secrets" {
  count = length(var.task_secret_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-exec-secrets"
  role  = aws_iam_role.ecs_task_execution.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.task_secret_arns }
  ] })
}

# Task role: what the application container itself may call.
resource "aws_iam_role" "ecs_task" {
  name               = "${var.project_name}-ecs-task-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ecs-tasks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_role_policy" "ecs_task_s3" {
  count = var.production_bucket_arn == "" ? 0 : 1
  name  = "${var.project_name}-task-s3"
  role  = aws_iam_role.ecs_task.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:ListBucket"], Resource = var.production_bucket_arn },
    { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${var.production_bucket_arn}/*" }
  ] })
}

resource "aws_iam_role_policy" "ecs_task_secrets" {
  count = length(var.task_secret_arns) > 0 ? 1 : 0
  name  = "${var.project_name}-task-secrets"
  role  = aws_iam_role.ecs_task.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["secretsmanager:GetSecretValue"], Resource = var.task_secret_arns }
  ] })
}
