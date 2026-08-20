resource "aws_key_pair" "devops" {
  key_name   = "${var.project_name}-${var.environment}-devops-key"
  public_key = file(pathexpand(var.ssh_public_key_path))

  tags = {
    Name = "${var.project_name}-${var.environment}-devops-key"
  }
}

module "jenkins_controller" {
  source = "../../modules/ec2"

  name          = "${var.project_name}-${var.environment}-jenkins-controller"
  role          = "jenkins-controller"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  subnet_id = module.vpc.public_subnet_ids[0]

  security_group_ids = [
    aws_security_group.jenkins_controller.id
  ]

  key_name             = aws_key_pair.devops.key_name
  iam_instance_profile = aws_iam_instance_profile.devops_host["jenkins-controller"].name

  root_volume_size = 20
}

module "jenkins_agent" {
  source = "../../modules/ec2"

  name          = "${var.project_name}-${var.environment}-jenkins-agent"
  role          = "jenkins-agent"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id = module.vpc.public_subnet_ids[1]

  security_group_ids = [
    aws_security_group.jenkins_agent.id
  ]

  key_name             = aws_key_pair.devops.key_name
  iam_instance_profile = aws_iam_instance_profile.devops_host["jenkins-agent"].name

  root_volume_size = 30
}

module "sonarqube" {
  source = "../../modules/ec2"

  name          = "${var.project_name}-${var.environment}-sonarqube"
  role          = "sonarqube"
  ami_id        = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"

  subnet_id = module.vpc.public_subnet_ids[0]

  security_group_ids = [
    aws_security_group.sonarqube.id
  ]

  key_name             = aws_key_pair.devops.key_name
  iam_instance_profile = aws_iam_instance_profile.devops_host["sonarqube"].name

  root_volume_size = 30
}
