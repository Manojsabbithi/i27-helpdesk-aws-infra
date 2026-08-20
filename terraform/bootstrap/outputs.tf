output "terraform_state_bucket" {
  description = "S3 bucket used for Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

output "aws_account_id" {
  description = "AWS account being used"
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "AWS region being used"
  value       = var.aws_region
}
