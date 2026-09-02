# ============================================================
# i27 Helpdesk - Attachment Storage
# ============================================================

data "aws_caller_identity" "attachment" {}

locals {
  attachment_service_account = "i27-helpdesk-attachment"

  attachment_oidc_issuer = replace(
    data.aws_eks_cluster.lbc.identity[0].oidc[0].issuer,
    "https://",
    ""
  )

  attachment_bucket_name = "${var.project_name}-${var.environment}-attachments-${data.aws_caller_identity.attachment.account_id}"
}

# ------------------------------------------------------------
# Private S3 bucket for helpdesk attachments
# ------------------------------------------------------------

resource "aws_s3_bucket" "attachments" {
  bucket = local.attachment_bucket_name

  tags = {
    Name        = local.attachment_bucket_name
    Project     = var.project_name
    Environment = var.environment
  }
}

# Never allow this bucket to become public.
resource "aws_s3_bucket_public_access_block" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Disable ACL ownership model.
resource "aws_s3_bucket_ownership_controls" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Encrypt all objects at rest.
resource "aws_s3_bucket_server_side_encryption_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# This is a DEV environment.
# Automatically remove test attachments after 30 days.
resource "aws_s3_bucket_lifecycle_configuration" "attachments" {
  bucket = aws_s3_bucket.attachments.id

  rule {
    id     = "expire-dev-attachments"
    status = "Enabled"

    filter {
      prefix = "attachments/"
    }

    expiration {
      days = 30
    }
  }
}

# Require TLS when accessing the S3 bucket.
data "aws_iam_policy_document" "attachment_bucket_tls" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    actions = [
      "s3:*"
    ]

    resources = [
      aws_s3_bucket.attachments.arn,
      "${aws_s3_bucket.attachments.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "attachments" {
  bucket = aws_s3_bucket.attachments.id
  policy = data.aws_iam_policy_document.attachment_bucket_tls.json

  depends_on = [
    aws_s3_bucket_public_access_block.attachments
  ]
}

# ============================================================
# IRSA - Attachment Service
# ============================================================

# Only the exact Attachment Kubernetes ServiceAccount
# may assume this IAM role.
data "aws_iam_policy_document" "attachment_s3_assume_role" {
  statement {
    sid     = "AllowAttachmentServiceAccount"
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
      variable = "${local.attachment_oidc_issuer}:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.attachment_oidc_issuer}:sub"

      values = [
        "system:serviceaccount:i27-helpdesk-dev:${local.attachment_service_account}"
      ]
    }
  }
}

resource "aws_iam_role" "attachment_s3" {
  name = "${var.project_name}-${var.environment}-attachment-s3-role"

  assume_role_policy = data.aws_iam_policy_document.attachment_s3_assume_role.json

  tags = {
    Name = "${var.project_name}-${var.environment}-attachment-s3-role"
  }
}

# Least privilege:
# Attachment service may upload and download attachment objects only.
data "aws_iam_policy_document" "attachment_s3" {
  statement {
    sid    = "AttachmentObjectAccess"
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.attachments.arn}/attachments/*"
    ]
  }

  statement {
    sid    = "AttachmentBucketList"
    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.attachments.arn
    ]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"

      values = [
        "attachments/*"
      ]
    }
  }
}

resource "aws_iam_role_policy" "attachment_s3" {
  name = "${var.project_name}-${var.environment}-attachment-s3"
  role = aws_iam_role.attachment_s3.id

  policy = data.aws_iam_policy_document.attachment_s3.json
}

# ============================================================
# Outputs
# ============================================================

output "attachment_bucket_name" {
  description = "Private S3 bucket used by the attachment service"
  value       = aws_s3_bucket.attachments.bucket
}

output "attachment_s3_role_arn" {
  description = "IAM role used by the attachment service through IRSA"
  value       = aws_iam_role.attachment_s3.arn
}
