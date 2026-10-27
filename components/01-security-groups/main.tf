# shortcut: reads the sibling component's local state; switch backend/config
# to s3 (bucket/key/region) after remote-state migration.
data "terraform_remote_state" "network" {
  count   = var.vpc_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../00-network/terraform.tfstate" }
}

locals {
  vpc_id = var.vpc_id != "" ? var.vpc_id : data.terraform_remote_state.network[0].outputs.vpc_id
}

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Public ALB ingress only"
  vpc_id      = local.vpc_id
  ingress {
    description = "HTTP; only used for the HTTPS redirect once a certificate listener exists"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS ingress for approved certificate-backed listener"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_security_group" "staging" {
  name        = "${var.project_name}-staging-sg"
  description = "Staging EC2; SSH restricted to the approved administrator CIDR"
  vpc_id      = local.vpc_id
  ingress {
    description = "SSH from approved administrator public IP/CIDR only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ssh_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-staging-sg", Environment = "staging" }
}

resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Production ECS hosts/tasks"
  vpc_id      = local.vpc_id
  ingress {
    description     = "Application traffic only from ALB SG"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-ecs-sg", Environment = "production" }
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "PostgreSQL only from staging and production application SGs"
  vpc_id      = local.vpc_id
  ingress {
    description     = "PostgreSQL from staging EC2"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.staging.id]
  }
  ingress {
    description     = "PostgreSQL from production ECS hosts"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { Name = "${var.project_name}-rds-sg" }
}
