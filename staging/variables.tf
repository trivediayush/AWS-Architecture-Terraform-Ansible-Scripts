variable "aws_region" {
  description = "Approved AWS region."
  type        = string
}
variable "project_name" {
  description = "Short project tag prefix."
  type        = string
  default     = "sunroof"
}
variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "staging"
}

# --- ec2 ---

variable "subnet_id" {
  description = "Optional override; empty uses shared public_subnet_ids[0]. Point at another public subnet if its AZ runs out of capacity."
  type        = string
  default     = ""
}
variable "key_pair_name" {
  description = "Name of an existing EC2 key pair; retain its matching private PEM file securely."
  type        = string
  default     = "sunroof-key"
}
variable "instance_type" {
  description = "x86_64 instance type — must match the x86_64 AMI filter in main.tf."
  type        = string
  default     = "t3.medium"
}
variable "root_volume_size_gb" {
  type    = number
  default = 30
}
variable "associate_public_ip_address" {
  description = "Staging EC2 uses SSH with the supplied key pair. Public IP is needed if connecting directly over the internet."
  type        = bool
  default     = true
}
variable "ami_id_override" {
  description = "Optional approved x86_64 AMI ID; otherwise latest Amazon Linux 2023 x86_64 via EC2 API."
  type        = string
  default     = ""
}

# --- s3 ---

variable "bucket_name" {
  description = "Globally unique staging bucket name; set explicitly."
  type        = string
}

# --- alarms ---

variable "log_retention_days" {
  type    = number
  default = 30
}
