resource "aws_security_group" "jenkins_controller" {
  name        = "${var.project_name}-${var.environment}-jenkins-controller-sg"
  description = "Security group for Jenkins Controller"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-controller-sg"
  }
}

resource "aws_security_group" "jenkins_agent" {
  name        = "${var.project_name}-${var.environment}-jenkins-agent-sg"
  description = "Security group for Jenkins Agent"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-jenkins-agent-sg"
  }
}

resource "aws_security_group" "sonarqube" {
  name        = "${var.project_name}-${var.environment}-sonarqube-sg"
  description = "Security group for SonarQube"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "${var.project_name}-${var.environment}-sonarqube-sg"
  }
}

# Jenkins Controller - SSH from your Mac
resource "aws_vpc_security_group_ingress_rule" "jenkins_controller_ssh" {
  security_group_id = aws_security_group.jenkins_controller.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  description = "SSH from administrator IP"
}

# Jenkins UI from your Mac
resource "aws_vpc_security_group_ingress_rule" "jenkins_controller_web" {
  security_group_id = aws_security_group.jenkins_controller.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 8080
  to_port           = 8080
  ip_protocol       = "tcp"

  description = "Jenkins UI from administrator IP"
}

# Jenkins Controller outbound
resource "aws_vpc_security_group_egress_rule" "jenkins_controller_outbound" {
  security_group_id = aws_security_group.jenkins_controller.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Jenkins Agent - SSH from your Mac
resource "aws_vpc_security_group_ingress_rule" "jenkins_agent_ssh_admin" {
  security_group_id = aws_security_group.jenkins_agent.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  description = "SSH from administrator IP"
}

# Jenkins Controller -> Jenkins Agent
resource "aws_vpc_security_group_ingress_rule" "jenkins_agent_ssh_controller" {
  security_group_id            = aws_security_group.jenkins_agent.id
  referenced_security_group_id = aws_security_group.jenkins_controller.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"

  description = "SSH from Jenkins Controller"
}

resource "aws_vpc_security_group_egress_rule" "jenkins_agent_outbound" {
  security_group_id = aws_security_group.jenkins_agent.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# SonarQube - SSH from your Mac
resource "aws_vpc_security_group_ingress_rule" "sonarqube_ssh" {
  security_group_id = aws_security_group.sonarqube.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"

  description = "SSH from administrator IP"
}

# SonarQube UI from your Mac
resource "aws_vpc_security_group_ingress_rule" "sonarqube_web_admin" {
  security_group_id = aws_security_group.sonarqube.id
  cidr_ipv4         = var.admin_cidr
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"

  description = "SonarQube UI from administrator IP"
}

# Jenkins needs to call SonarQube
resource "aws_vpc_security_group_ingress_rule" "sonarqube_from_jenkins" {
  security_group_id            = aws_security_group.sonarqube.id
  referenced_security_group_id = aws_security_group.jenkins_controller.id
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"

  description = "SonarQube from Jenkins Controller"
}

resource "aws_vpc_security_group_egress_rule" "sonarqube_outbound" {
  security_group_id = aws_security_group.sonarqube.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
