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

variable "private_subnet_ids" {
  description = "Optional override; empty reads app_subnet_ids from 00-network state."
  type        = list(string)
  default     = []
}
variable "ecs_security_group_id" {
  description = "Optional override; empty reads ecs_security_group_id from 01-security-groups state."
  type        = string
  default     = ""
}
variable "ecs_instance_profile_name" {
  description = "Optional override; empty reads ecs_instance_profile_name from 02-iam state."
  type        = string
  default     = ""
}
variable "key_pair_name" {
  description = "Existing EC2 key pair name for administrative SSH when network access is available (e.g. VPN/bastion)."
  type        = string
  default     = "sunroof-key"
}
variable "instance_type" {
  type    = string
  default = "t3.small"
}
variable "root_volume_size_gb" {
  type    = number
  default = 100
}
variable "desired_capacity" {
  type    = number
  default = 2
}
variable "min_size" {
  type    = number
  default = 2
}
variable "max_size" {
  type    = number
  default = 2
}
variable "ecs_cluster_name" {
  type    = string
  default = "sunroof-production"
}
