provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "i27-helpdesk"
      Environment = "shared"
      ManagedBy   = "Terraform"
      Owner       = "Manoj"
    }
  }
}
