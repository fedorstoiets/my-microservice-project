# Optional platform add-ons. Both disabled while state migration and IAM permissions are unresolved.
variable "enable_metrics_server" {
  type    = bool
  default = false
}
resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"
  wait       = true
  timeout    = 900
}
variable "enable_external_secrets" {
  type    = bool
  default = false
  validation {
    condition     = !var.enable_external_secrets || (var.enable_irsa && var.deploy_database && var.external_secrets_chart_version != null)
    error_message = "External Secrets requires enable_irsa=true, deploy_database=true and an explicitly pinned external_secrets_chart_version. Secret provisioning and rollout remain subject to migration HOLD."
  }
}
resource "helm_release" "external_secrets" {
  count            = var.enable_external_secrets ? 1 : 0
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  # Helm chart version must be pinned after repository-index verification; override via variable.
  version = var.external_secrets_chart_version
  wait    = true
  timeout = 900
  values = [yamlencode({
    serviceAccount = { create = true, name = "external-secrets", annotations = { "eks.amazonaws.com/role-arn" = try(aws_iam_role.external_secrets[0].arn, null) } }
  })]
}
variable "external_secrets_chart_version" {
  type    = string
  default = null
}
# The controller must have an IRSA role; enable only together with enable_irsa.
resource "aws_iam_role" "external_secrets" {
  count = var.enable_external_secrets && var.enable_irsa ? 1 : 0
  name  = "${var.cluster_name}-external-secrets-irsa"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRoleWithWebIdentity",
      Principal = { Federated = local.oidc_provider_arn },
      Condition = { StringEquals = {
        "${local.oidc_hostpath}:aud" = "sts.amazonaws.com",
        "${local.oidc_hostpath}:sub" = "system:serviceaccount:external-secrets:external-secrets"
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
resource "aws_iam_role_policy" "external_secrets_rds" {
  count = var.enable_external_secrets && var.enable_irsa ? 1 : 0
  role  = aws_iam_role.external_secrets[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect   = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
    Resource = concat([module.rds[0].master_secret_arn], var.external_secrets_additional_secret_arns, local.delivery_secret_arns)
  }] })
}

variable "external_secrets_additional_secret_arns" {
  description = "Explicit signing/GitOps/application secret ARNs for an authorized ESO rollout; no wildcard access."
  type        = list(string)
  default     = []
}
