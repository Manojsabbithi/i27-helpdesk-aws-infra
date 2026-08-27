variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "i27-helpdesk"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "admin_cidr" {
  description = "Public IP CIDR allowed to access DevOps EC2 instances"
  type        = string
}

variable "ssh_public_key_path" {
  description = "Local path to the SSH public key"
  type        = string
  default     = "~/.ssh/i27-helpdesk-aws.pub"
}

variable "devops_ami_id" {
  description = "Pinned Ubuntu AMI for long-lived DevOps EC2 instances"
  type        = string
}

variable "alert_email" {
  description = "Email address for infrastructure monitoring alerts"
  type        = string
}
