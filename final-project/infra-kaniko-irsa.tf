resource "aws_iam_role" "kaniko_irsa" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-kaniko-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = { StringEquals = {
        "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        "${local.oidc_hostpath}:sub" = "system:serviceaccount:jenkins:kaniko-builder"
      } }
    }]
  })
  lifecycle {
    precondition {
      condition     = local.oidc_provider_verified
      error_message = "IRSA role creation is blocked: verified issuer/audience must match this cluster."
    }
  }
}
resource "aws_iam_role_policy" "kaniko_irsa_ecr" {
  count = var.enable_irsa ? 1 : 0
  role  = aws_iam_role.kaniko_irsa[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
    { Effect   = "Allow",
      Action   = ["ecr:DescribeImages", "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"],
      Resource = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.goaldevops.account_id}:repository/${var.ecr_repository_name}"
    }
  ] })
}
