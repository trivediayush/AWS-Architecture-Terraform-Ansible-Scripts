resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Internet-facing ALB: HTTP from the configured admin CIDR only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-alb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = var.allowed_admin_cidr
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from allowed_admin_cidr"
}

resource "aws_vpc_security_group_egress_rule" "alb_out" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound (ALB must reach task ENIs)"
}

# Security group for the EC2 container hosts themselves. awsvpc tasks get their
# own ENIs + SG. Hosts are private (no public IP); SSH is allowed from inside
# the VPC only, using the key pair configured on the launch template.
resource "aws_security_group" "ecs_hosts" {
  name        = "${var.project_name}-ecs-hosts"
  description = "ECS container hosts - SSH from VPC only, outbound to ECS/ECR/NAT"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-ecs-hosts-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "ecs_hosts_ssh" {
  security_group_id = aws_security_group.ecs_hosts.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  description       = "SSH from inside the VPC only (sunroof-key)"
}

resource "aws_vpc_security_group_egress_rule" "ecs_hosts_out" {
  security_group_id = aws_security_group.ecs_hosts.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound (image pulls, ECS agent)"
}

# Security group attached to task ENIs (awsvpc mode).
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "ECS task ENIs: app ports from ALB, MQTT from inside the SG"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-ecs-tasks-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "tasks_from_alb" {
  for_each = toset(["80", "5678", "5679", "9001"])

  security_group_id            = aws_security_group.ecs_tasks.id
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = tonumber(each.key)
  to_port                      = tonumber(each.key)
  ip_protocol                  = "tcp"
  description                  = "App port ${each.key} from ALB"
}

# Native MQTT/TCP 1883 is internal-only: only other task ENIs (and, if you later
# allow it, anything you attach this SG to) can reach the broker.
resource "aws_vpc_security_group_ingress_rule" "tasks_mqtt_internal" {
  security_group_id            = aws_security_group.ecs_tasks.id
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  from_port                    = 1883
  to_port                      = 1883
  ip_protocol                  = "tcp"
  description                  = "MQTT 1883 between tasks inside the VPC only"
}

resource "aws_vpc_security_group_egress_rule" "ecs_tasks_out" {
  security_group_id = aws_security_group.ecs_tasks.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound (image pulls, CloudWatch logs)"
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds"
  description = "RDS: DB port from ECS tasks only"
  vpc_id      = aws_vpc.main.id

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_tasks" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = aws_security_group.ecs_tasks.id
  from_port                    = local.db_port
  to_port                      = local.db_port
  ip_protocol                  = "tcp"
  description                  = "DB port from ECS task ENIs"
}

resource "aws_vpc_security_group_egress_rule" "rds_out" {
  security_group_id = aws_security_group.rds.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "All outbound"
}
