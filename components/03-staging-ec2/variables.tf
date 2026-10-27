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
  default     = "shared"
}

variable "subnet_id" {
  description = "Optional override; empty reads public_subnet_ids[0] from 00-network state."
  type        = string
  default     = ""
}
variable "security_group_id" {
  description = "Optional override; empty reads staging_security_group_id from 01-security-groups state."
  type        = string
  default     = ""
}
variable "instance_profile_name" {
  description = "Optional override; empty reads staging_instance_profile_name from 02-iam state."
  type        = string
  default     = ""
}
variable "key_pair_name" {
  description = "Name of an existing EC2 key pair; retain its matching private PEM file securely."
  type        = string
  default     = "sunroof-key"
}
variable "instance_type" {
  description = "ARM64 instance type — must match the ARM64 AMI filter in main.tf."
  type        = string
  default     = "t4g.medium"
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
  description = "Optional approved ARM64 AMI ID; otherwise latest Amazon Linux 2023 ARM64 via public AWS Parameter Store."
  type        = string
  default     = ""
}
