resource "kubernetes_service_account_v1" "verifier" {
  metadata {
    name      = "goaldevops-verifier"
    namespace = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  }
}
resource "kubernetes_namespace_v1" "app" {
  metadata { name = "neoversity" }
}
resource "kubernetes_role_v1" "verify_app" {
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
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
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.app.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.verify_app.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.verifier.metadata[0].name
    namespace = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  }
}
resource "kubernetes_role_v1" "verify_argo" {
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.platform["argocd"].metadata[0].name
  }
  rule {
    api_groups     = ["argoproj.io"]
    resources      = ["applications"]
    resource_names = ["django-gitops"]
    verbs          = ["get"]
  }
}
resource "kubernetes_role_binding_v1" "verify_argo" {
  metadata {
    name      = "goaldevops-verify"
    namespace = kubernetes_namespace_v1.platform["argocd"].metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.verify_argo.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.verifier.metadata[0].name
    namespace = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  }
}
