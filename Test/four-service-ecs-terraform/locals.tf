locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }

  # Use the first two AZs the region reports as available (3 exist in ap-south-1).
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  db_port = var.db_engine == "postgres" ? 5432 : 3306
  db_engine_version = var.db_engine_version != "" ? var.db_engine_version : (
    var.db_engine == "postgres" ? "16" : "8.0"
  )

  bucket_name = var.s3_bucket_name != "" ? var.s3_bucket_name : "${var.project_name}-app-${data.aws_caller_identity.current.account_id}"

  # One log group for the whole cluster; each service gets its own stream prefix.
  log_group_name = "/ecs/${var.project_name}"
}
