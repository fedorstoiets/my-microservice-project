resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  namespace  = var.namespace
  version    = var.chart_version
  timeout    = 1200
  wait       = true
  depends_on = [kubernetes_config_map_v1.build]
  values     = var.values_override != null ? var.values_override : [templatefile("${path.module}/values.yaml", { source_repo = var.source_repo, source_branch = var.source_branch, existing_claim = var.existing_claim, existing_claim_sub_path = var.existing_claim_sub_path, ci_tools_image = lookup(var.build_config, "CI_TOOLS_IMAGE", ""), kaniko_image = lookup(var.build_config, "KANIKO_IMAGE", ""), kaniko_config_map = lookup(var.build_config, "KANIKO_CONFIG_MAP", "kaniko-docker-config"), persistence_enabled = var.persistence_enabled })]
}

resource "kubernetes_config_map_v1" "build" {
  count = length(var.build_config) > 0 ? 1 : 0
  metadata {
    name      = "goaldevops-build-config"
    namespace = var.namespace
  }
  data = var.build_config
}
