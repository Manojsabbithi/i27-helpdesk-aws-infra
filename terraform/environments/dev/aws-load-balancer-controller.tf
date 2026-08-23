# ============================================================
# AWS Load Balancer Controller - IRSA
# ============================================================

data "aws_eks_cluster" "lbc" {
  name = module.eks.cluster_name
}

# Retrieve the certificate used by the EKS OIDC endpoint.
data "tls_certificate" "eks_oidc" {
  url = data.aws_eks_cluster.lbc.identity[0].oidc[0].issuer
}

locals {
  eks_oidc_issuer = data.aws_eks_cluster.lbc.identity[0].oidc[0].issuer

  eks_oidc_provider = replace(
    data.aws_eks_cluster.lbc.identity[0].oidc[0].issuer,
    "https://",
    ""
  )
}

# ------------------------------------------------------------
# IAM OIDC Provider for EKS / IRSA
# ------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "eks" {
  url = local.eks_oidc_issuer

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    data.tls_certificate.eks_oidc.certificates[0].sha1_fingerprint
  ]

  tags = {
    Name        = "${module.eks.cluster_name}-oidc"
    Project     = "i27-helpdesk"
    Environment = "dev"
  }
}

# ------------------------------------------------------------
# Trust policy
#
# Only this exact Kubernetes ServiceAccount can assume
# the AWS Load Balancer Controller IAM role.
# ------------------------------------------------------------

data "aws_iam_policy_document" "aws_load_balancer_controller_assume_role" {

  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.eks.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.eks_oidc_provider}:sub"

      values = [
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

# ------------------------------------------------------------
# IAM policy containing the AWS LBC permissions
# ------------------------------------------------------------

resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "${module.eks.cluster_name}-aws-lbc-policy"

  description = "IAM permissions for AWS Load Balancer Controller"

  policy = file(
    "${path.module}/policies/aws-load-balancer-controller-iam-policy.json"
  )

  tags = {
    Project     = "i27-helpdesk"
    Environment = "dev"
  }
}

# ------------------------------------------------------------
# Dedicated IAM role for the controller
# ------------------------------------------------------------

resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "${module.eks.cluster_name}-aws-lbc-role"

  assume_role_policy = data.aws_iam_policy_document.aws_load_balancer_controller_assume_role.json

  tags = {
    Project     = "i27-helpdesk"
    Environment = "dev"
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}

# ------------------------------------------------------------
# Useful for the Helm / Kubernetes ServiceAccount configuration
# ------------------------------------------------------------

output "aws_load_balancer_controller_role_arn" {
  description = "IRSA IAM role used by AWS Load Balancer Controller"
  value       = aws_iam_role.aws_load_balancer_controller.arn
}
