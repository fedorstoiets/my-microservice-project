resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = var.namespace
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  timeout    = 1200
  wait       = true
  values     = [file("${path.module}/values.yaml")]
}

resource "helm_release" "applications" {
  name       = "neoversity-apps"
  namespace  = var.namespace
  chart      = "${path.module}/charts/applications"
  timeout    = 600
  wait       = true
  values = [yamlencode({
    repoURL        = var.gitops_repo
    targetRevision = var.gitops_branch
    appNamespace   = var.app_namespace
  })]
  depends_on = [helm_release.argocd]
}
