terraform {
  backend "s3" {
    bucket       = "i27-helpdesk-tfstate-209003640756-ap-south-2"
    key          = "bootstrap/terraform.tfstate"
    region       = "ap-south-2"
    encrypt      = true
    use_lockfile = true
  }
}
