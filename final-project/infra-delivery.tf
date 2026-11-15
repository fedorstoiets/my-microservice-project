# Additive existing-environment delivery resources. All disabled until reviewed rollout approval.
variable "prepare_jenkins_storage" {
  type    = bool
  default = false
  validation {
    condition     = !var.prepare_jenkins_storage || var.enable_ebs_csi
    error_message = "Prepare Jenkins storage only after authorized CSI/IRSA prerequisites."
  }
}
variable "jenkins_restore_verified" {
  description = "Attest to application-consistent backup and tested restore onto this exact claim; not authorization."
  type        = bool
  default     = false
}
variable "enable_delivery_v2" {
  type    = bool
  default = false
  validation {
    condition = !var.enable_delivery_v2 || (
      var.prepare_jenkins_storage && var.jenkins_restore_verified && var.enable_irsa && var.enable_external_secrets &&
      var.delivery_inputs != null && var.continuity_jenkins_values == null
    )
    error_message = "Delivery cutover requires verified restored storage, IRSA/ESO, complete inputs, and deliberately released Jenkins continuity values; keep Application/server overrides frozen until their own reviewed phase. Do not restart ephemeral Jenkins before recovery."
  }
}
variable "enable_application_sync" {
  type    = bool
  default = false
  validation {
    condition     = !var.enable_application_sync || (var.enable_delivery_v2 && var.continuity_argocd_values == null && var.continuity_applications_values == null)
    error_message = "Application sync requires the separately approved delivery cutover."
  }
}
variable "enable_database_bootstrap" {
  type    = bool
  default = false
  validation {
    condition     = !var.enable_database_bootstrap || var.enable_application_sync
    error_message = "Database bootstrap requires separate SQL authorization and enabled application sync."
  }
}
variable "delivery_inputs" {
  description = "Actual reviewed metadata only; provision secret values outside Terraform through an approved channel."
  type = object({
    ci_tools_image = string, kaniko_image = string,
    app_secret_arn = string, signing_secret_arn = string, gitops_secret_arn = string,
    kms_key_arns   = list(string), reviewed_gitops_base = optional(string, "")
  })
  default = null
  validation {
    condition = var.delivery_inputs == null ? true : (
      can(regex("@sha256:[a-f0-9]{64}$", var.delivery_inputs.ci_tools_image)) &&
      can(regex("@sha256:[a-f0-9]{64}$", var.delivery_inputs.kaniko_image)) && !startswith(var.delivery_inputs.kaniko_image, "gcr.io/kaniko-project/") &&
      alltrue([for arn in [var.delivery_inputs.app_secret_arn, var.delivery_inputs.signing_secret_arn, var.delivery_inputs.gitops_secret_arn] : can(regex("^arn:[^:]+:secretsmanager:[^:]+:[0-9]{12}:secret:.+$", arn))])
    )
    error_message = "Use verified image digests and actual Secrets Manager ARNs; never secret values or guessed identifiers."
  }
}
locals {
  delivery_metadata = var.delivery_inputs == null ? {
    ci_tools_image = "", kaniko_image = "", app_secret_arn = "", signing_secret_arn = "", gitops_secret_arn = "", kms_key_arns = [], reviewed_gitops_base = ""
  } : var.delivery_inputs
  delivery_secret_arns = var.enable_delivery_v2 ? [local.delivery_metadata.app_secret_arn, local.delivery_metadata.signing_secret_arn, local.delivery_metadata.gitops_secret_arn] : []
}
resource "kubernetes_persistent_volume_claim_v1" "jenkins_home" {
  count = var.prepare_jenkins_storage ? 1 : 0
  metadata {
    name      = "jenkins-home"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.gp3[0].metadata[0].name
    resources { requests = { storage = "8Gi" } }
  }
  wait_until_bound = false
  lifecycle { prevent_destroy = true }
}
resource "helm_release" "delivery_secrets" {
  count      = var.enable_delivery_v2 ? 1 : 0
  name       = "platform-secrets"
  namespace  = "external-secrets"
  chart      = "${path.module}/charts/platform-secrets"
  wait       = true
  timeout    = 600
  values     = [yamlencode({ region = var.aws_region, gitopsSecretArn = local.delivery_metadata.gitops_secret_arn, gitopsRepo = var.github_gitops_repo })]
  depends_on = [helm_release.external_secrets]
  lifecycle {
    precondition {
      condition     = local.delivery_metadata.app_secret_arn != module.rds[0].master_secret_arn
      error_message = "The web application must not receive the RDS master secret."
    }
  }
}
resource "kubernetes_config_map_v1" "delivery_kaniko" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-kaniko-config"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
  data = { "config.json" = jsonencode({ credHelpers = { (split("/", module.ecr.repository_url)[0]) = "ecr-login" } }) }
}
resource "aws_iam_role_policy" "delivery_secret_kms" {
  count = var.enable_delivery_v2 && length(local.delivery_metadata.kms_key_arns) > 0 ? 1 : 0
  role  = aws_iam_role.external_secrets[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "kms:Decrypt", Resource = local.delivery_metadata.kms_key_arns,
  Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com" } } }] })
}

resource "kubernetes_service_account_v1" "verifier" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-verifier"
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}
resource "kubernetes_role_v1" "verify_app" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-verify"
    namespace = "neoversity"
  }
  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = [""]
    resources  = ["pods", "services"]
    verbs      = ["get", "list", "watch"]
  }
}
resource "kubernetes_role_binding_v1" "verify_app" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-verify"
    namespace = "neoversity"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.verify_app[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.verifier[0].metadata[0].name
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}
resource "kubernetes_role_v1" "verify_argo" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  rule {
    api_groups     = ["argoproj.io"]
    resources      = ["applications"]
    resource_names = ["django-gitops"]
    verbs          = ["get"]
  }
}
resource "kubernetes_role_binding_v1" "verify_argo" {
  count = var.enable_delivery_v2 ? 1 : 0
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.verify_argo[0].metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.verifier[0].metadata[0].name
    namespace = kubernetes_namespace_v1.jenkins.metadata[0].name
  }
}

variable "enable_application_pruning" {
  description = "Keep false until legacy resource/data ownership and every proposed deletion are separately reviewed."
  type        = bool
  default     = false
}
