# shortcut: reads sibling components' local state; switch backend/config to s3
# after remote-state migration.
data "terraform_remote_state" "network" {
  count   = length(var.database_subnet_ids) == 0 ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../00-network/terraform.tfstate" }
}
data "terraform_remote_state" "security" {
  count   = var.rds_security_group_id == "" ? 1 : 0
  backend = "local"
  config  = { path = "${path.module}/../01-security-groups/terraform.tfstate" }
}

locals {
  database_subnet_ids   = length(var.database_subnet_ids) > 0 ? var.database_subnet_ids : data.terraform_remote_state.network[0].outputs.database_subnet_ids
  rds_security_group_id = var.rds_security_group_id != "" ? var.rds_security_group_id : data.terraform_remote_state.security[0].outputs.rds_security_group_id
}

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
  tags                            = { Name = var.db_identifier, Environment = "shared" }
}
