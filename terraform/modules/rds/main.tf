resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-mysql-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.name_prefix}-mysql-subnet-group"
  }
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-mysql-sg"
  description = "Security group for i27 Helpdesk MySQL RDS"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.name_prefix}-mysql-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "mysql" {
  for_each = var.allowed_security_group_ids

  security_group_id            = aws_security_group.this.id
  referenced_security_group_id = each.value

  from_port   = 3306
  to_port     = 3306
  ip_protocol = "tcp"

  description = "MySQL access from approved security group"
}

resource "aws_db_instance" "this" {
  identifier = "${var.name_prefix}-mysql"

  engine         = "mysql"
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type       = "gp3"
  storage_encrypted  = true

  username                    = var.master_username
  manage_master_user_password = true

  port = 3306

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  publicly_accessible = false
  multi_az            = false

  backup_retention_period = 1

  performance_insights_enabled = false
  monitoring_interval           = 0

  auto_minor_version_upgrade = true
  apply_immediately           = true

  deletion_protection = false
  skip_final_snapshot = true

  copy_tags_to_snapshot = true

  tags = {
    Name = "${var.name_prefix}-mysql"
  }
}
