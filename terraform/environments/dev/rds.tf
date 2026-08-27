module "rds" {
  source = "../../modules/rds"

  name_prefix = "${var.project_name}-${var.environment}"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids

  # Jenkins Agent can perform DB validation/migrations.
  # Later we will also allow the EKS worker-node security group.
  allowed_security_group_ids = [
    aws_security_group.jenkins_agent.id
  ]

  instance_class    = "db.t3.micro"
  allocated_storage = 20
  master_username   = "helpdeskadmin"
}
