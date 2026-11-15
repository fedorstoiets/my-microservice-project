resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version
  timeout    = 1200
  wait       = true
  values     = var.values_override != null ? var.values_override : [file("${path.module}/values.yaml")]
}

resource "helm_release" "applications" {
  name      = "neoversity-apps"
  namespace = var.namespace
  chart     = "${path.module}/charts/applications"
  timeout   = 600
  wait      = true
  values = var.applications_values_override != null ? var.applications_values_override : [yamlencode({
    repoURL        = var.gitops_repo
    targetRevision = var.gitops_branch
    appNamespace   = var.app_namespace
    rdsEndpoint    = var.rds_endpoint
    appValues      = var.helm_values
    enableAutoSync = var.enable_auto_sync
    enablePruning  = var.enable_pruning
  })]
  depends_on = [helm_release.argocd]
  lifecycle {
    precondition {
      condition     = var.applications_values_override != null || yamldecode(file("${path.module}/charts/applications/Chart.yaml")).version == "0.2.0"
      error_message = "Frozen legacy chart must keep its deployed values; restore and review canonical 0.2.0 before releasing Application overrides."
    }
  }
}
