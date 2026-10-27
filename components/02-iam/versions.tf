terraform {
  # Remote state: uncomment after bootstrap/ is applied and bucket is filled in.
  # backend "s3" {
  #   bucket       = "REPLACE_WITH_STATE_BUCKET"
  #   key          = "components/02-iam/terraform.tfstate"
  #   region       = "ap-south-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.project_name, ManagedBy = "Terraform" } }
}
