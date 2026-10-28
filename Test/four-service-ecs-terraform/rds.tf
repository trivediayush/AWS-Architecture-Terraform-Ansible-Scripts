resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = aws_subnet.db[*].id

  tags = { Name = "${var.project_name}-db-subnets" }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  engine            = var.db_engine
  engine_version    = local.db_engine_version
  instance_class    = var.db_instance_class
  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  multi_az               = true
  publicly_accessible    = false
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  port                   = local.db_port

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  backup_retention_period = 1
  backup_window           = "02:00-03:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  # Test environment: no final snapshot, allow fast destroy. Remove for real use.
  skip_final_snapshot   = true
  deletion_protection   = false
  copy_tags_to_snapshot = true

  tags = { Name = "${var.project_name}-db" }
}
