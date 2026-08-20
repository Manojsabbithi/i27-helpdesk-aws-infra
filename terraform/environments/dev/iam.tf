locals {
  devops_hosts = toset([
    "jenkins-controller",
    "jenkins-agent",
    "sonarqube"
  ])
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "devops_host" {
  for_each = local.devops_hosts

  name               = "${var.project_name}-${var.environment}-${each.key}-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  for_each = local.devops_hosts

  role       = aws_iam_role.devops_host[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "devops_host" {
  for_each = local.devops_hosts

  name = "${var.project_name}-${var.environment}-${each.key}-profile"
  role = aws_iam_role.devops_host[each.key].name
}
