output "vpc_id" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = module.vpc.vpc_cidr
}

output "availability_zones" {
  value = local.availability_zones
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "internet_gateway_id" {
  value = module.vpc.internet_gateway_id
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
}

output "jenkins_controller_public_ip" {
  value = module.jenkins_controller.public_ip
}

output "jenkins_controller_private_ip" {
  value = module.jenkins_controller.private_ip
}

output "jenkins_agent_public_ip" {
  value = module.jenkins_agent.public_ip
}

output "jenkins_agent_private_ip" {
  value = module.jenkins_agent.private_ip
}

output "sonarqube_public_ip" {
  value = module.sonarqube.public_ip
}

output "sonarqube_private_ip" {
  value = module.sonarqube.private_ip
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoint" {
  value = module.rds.endpoint
}

output "rds_port" {
  value = module.rds.port
}

output "rds_security_group_id" {
  value = module.rds.security_group_id
}

output "rds_master_user_secret_arn" {
  value     = module.rds.master_user_secret_arn
  sensitive = true
}
