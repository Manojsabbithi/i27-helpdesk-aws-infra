resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id              = var.subnet_id
  vpc_security_group_ids = var.security_group_ids

  associate_public_ip_address = true

  key_name             = var.key_name
  iam_instance_profile = var.iam_instance_profile

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = var.root_volume_size
    encrypted             = true
    delete_on_termination = true
  }

  lifecycle {
    # Protect long-lived Jenkins/Sonar hosts from accidental replacement.
    prevent_destroy = true

    # Public IPv4 disappears while EC2 is stopped and can otherwise
    # create misleading ForceNew drift during Terraform planning.
    ignore_changes = [
      associate_public_ip_address
    ]
  }

  tags = {
    Name = var.name
    Role = var.role
  }
}
