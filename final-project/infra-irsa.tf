variable "enable_irsa" {
  type    = bool
  default = false
}
data "aws_caller_identity" "goaldevops" {}
resource "aws_iam_openid_connect_provider" "eks" {
  count          = var.enable_irsa && var.existing_oidc_provider_arn == null ? 1 : 0
  url            = module.eks.oidc_issuer
  client_id_list = ["sts.amazonaws.com"]
  # AWS IAM retrieves root certificate thumbprints when omitted (AWS provider v6).
}
locals {
  oidc_provider_verified = (!var.enable_irsa || var.existing_oidc_provider_arn == null) ? true : (
    replace(data.aws_iam_openid_connect_provider.existing[0].url, "https://", "") == local.oidc_hostpath &&
    contains(data.aws_iam_openid_connect_provider.existing[0].client_id_list, "sts.amazonaws.com")
  )
  oidc_provider_arn = var.enable_irsa ? (var.existing_oidc_provider_arn != null ? data.aws_iam_openid_connect_provider.existing[0].arn : aws_iam_openid_connect_provider.eks[0].arn) : null
  oidc_hostpath     = replace(module.eks.oidc_issuer, "https://", "")
}
resource "aws_iam_role" "ebs_csi" {
  count = var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-ebs-csi-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = local.oidc_provider_arn }
      Condition = { StringEquals = {
        "${local.oidc_hostpath}:aud" = "sts.amazonaws.com"
        "${local.oidc_hostpath}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
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
resource "aws_iam_role_policy_attachment" "ebs_csi" {
  count      = var.enable_irsa ? 1 : 0
  role       = aws_iam_role.ebs_csi[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

variable "existing_oidc_provider_arn" {
  description = "Actual verified externally owned IAM provider, if one already exists. Do not create/import duplicate ownership."
  type        = string
  default     = null
}
data "aws_iam_openid_connect_provider" "existing" {
  count = var.enable_irsa && var.existing_oidc_provider_arn != null ? 1 : 0
  arn   = var.existing_oidc_provider_arn
  # Keep this known-ARN read independent of pending EKS changes. The same issuer/
  # audience invariant is enforced by preconditions on every consuming IRSA role.
}
