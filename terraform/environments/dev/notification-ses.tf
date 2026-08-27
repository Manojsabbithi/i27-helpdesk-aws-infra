locals {
  notification_service_account = "i27-helpdesk-notification"

  notification_oidc_issuer = replace(
    data.aws_eks_cluster.lbc.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

# Trust policy:
# Only the Notification Kubernetes ServiceAccount can assume this role.
data "aws_iam_policy_document" "notification_ses_assume_role" {
  statement {
    sid     = "AllowNotificationServiceAccount"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.notification_oidc_issuer}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.notification_oidc_issuer}:sub"

      values = [
        "system:serviceaccount:i27-helpdesk-dev:${local.notification_service_account}"
      ]
    }
  }
}

resource "aws_iam_role" "notification_ses" {
  name = "${var.project_name}-${var.environment}-notification-ses-role"

  assume_role_policy = data.aws_iam_policy_document.notification_ses_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-notification-ses-role"
  }
}

# Permission policy:
# Notification service can SEND email, but cannot manage SES.
data "aws_iam_policy_document" "notification_ses" {
  statement {
    sid    = "AllowSESSendEmail"
    effect = "Allow"

    actions = [
      "ses:SendEmail"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "notification_ses" {
  name = "${var.project_name}-${var.environment}-notification-ses"
  role = aws_iam_role.notification_ses.id

  policy = data.aws_iam_policy_document.notification_ses.json
}

output "notification_ses_role_arn" {
  description = "IAM role used by the notification service through IRSA"
  value       = aws_iam_role.notification_ses.arn
}
