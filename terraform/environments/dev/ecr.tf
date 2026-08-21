module "ecr" {
  source = "../../modules/ecr"

  repository_names = [
    "i27-helpdesk/ui",
    "i27-helpdesk/gateway",
    "i27-helpdesk/auth-service",
    "i27-helpdesk/ticket-service",
    "i27-helpdesk/comment-service",
    "i27-helpdesk/notification-service"
  ]

  max_image_count = 10
}

data "aws_iam_policy_document" "jenkins_agent_ecr" {

  statement {
    sid = "ECRAuthorization"

    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  statement {
    sid = "ECRPushPull"

    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:DescribeImages",
      "ecr:ListImages"
    ]

    resources = values(module.ecr.repository_arns)
  }
}

resource "aws_iam_role_policy" "jenkins_agent_ecr" {
  name = "${var.project_name}-${var.environment}-jenkins-agent-ecr"
  role = aws_iam_role.devops_host["jenkins-agent"].id

  policy = data.aws_iam_policy_document.jenkins_agent_ecr.json
}
