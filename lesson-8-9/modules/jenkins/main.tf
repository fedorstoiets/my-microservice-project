resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = var.namespace
  timeout    = 1200
  wait       = true
  values     = [templatefile("${path.module}/values.yaml", { source_repo = var.source_repo })]
}
