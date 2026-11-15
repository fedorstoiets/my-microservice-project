# NEW ENVIRONMENTS ONLY. Requires completed infrastructure and private VPC access.
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
  }
  backend "s3" {
    key          = "goaldevops-v2/platform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
data "terraform_remote_state" "infra" {
  backend = "s3"
  config  = { bucket = var.state_bucket, key = var.infra_state_key, region = var.aws_region }
}
locals { infra = data.terraform_remote_state.infra.outputs.platform }
provider "aws" { region = var.aws_region }
data "aws_eks_cluster" "target" { name = local.infra.cluster_name }
provider "kubernetes" {
  host                   = data.aws_eks_cluster.target.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", local.infra.cluster_name]
  }
}
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.target.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.target.certificate_authority[0].data)
    exec                   = { api_version = "client.authentication.k8s.io/v1beta1", command = "aws", args = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", local.infra.cluster_name] }
  }
}
resource "kubernetes_namespace_v1" "platform" {
  for_each = toset(["jenkins", "argocd", "monitoring"])
  metadata { name = each.key }
}
resource "kubernetes_storage_class_v1" "gp3" {
  metadata { name = "gp3" }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  parameters             = { type = "gp3", encrypted = "true" }
}
resource "kubernetes_persistent_volume_claim_v1" "jenkins" {
  metadata {
    name      = "jenkins-home"
    namespace = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.gp3.metadata[0].name
    resources { requests = { storage = "8Gi" } }
  }
  wait_until_bound = false # WaitForFirstConsumer requires the Jenkins pod.
  lifecycle { prevent_destroy = true }
}
resource "helm_release" "eso" {
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.15.0"
  wait             = true
  timeout          = 900
  values           = [yamlencode({ serviceAccount = { create = true, name = "external-secrets", annotations = { "eks.amazonaws.com/role-arn" = local.infra.eso_role_arn } } })]
}
# Helm renders CRDs only after ESO is installed; avoids Kubernetes manifest schema discovery during plan.
resource "helm_release" "secrets" {
  name       = "platform-secrets"
  namespace  = "external-secrets"
  chart      = "${path.module}/../../charts/platform-secrets"
  wait       = true
  timeout    = 600
  values     = [yamlencode({ region = var.aws_region, gitopsSecretArn = local.infra.gitops_secret_arn, gitopsRepo = var.gitops_repo })]
  depends_on = [helm_release.eso, kubernetes_namespace_v1.platform]
}
resource "kubernetes_service_account_v1" "builder" {
  metadata {
    name        = "kaniko-builder"
    namespace   = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
    annotations = { "eks.amazonaws.com/role-arn" = local.infra.kaniko_role_arn }
  }
  automount_service_account_token = false
}
resource "kubernetes_config_map_v1" "kaniko" {
  metadata {
    name      = "goaldevops-kaniko-config"
    namespace = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  }
  data = { "config.json" = jsonencode({ credHelpers = { (split("/", local.infra.ecr_url)[0]) = "ecr-login" } }) }
}
module "jenkins" {
  source              = "../../modules/jenkins"
  namespace           = kubernetes_namespace_v1.platform["jenkins"].metadata[0].name
  source_repo         = var.source_repo
  source_branch       = "final-project"
  service_account     = kubernetes_service_account_v1.builder.metadata[0].name
  chart_version       = "5.12.0"
  persistence_enabled = true
  existing_claim      = kubernetes_persistent_volume_claim_v1.jenkins.metadata[0].name
  build_config = {
    ECR_URL              = local.infra.ecr_url
    AWS_REGION           = var.aws_region
    GITOPS_REPO          = var.gitops_repo
    GITOPS_REVIEWED_BASE = var.reviewed_gitops_base
    CI_TOOLS_IMAGE       = var.ci_tools_image
    KANIKO_IMAGE         = var.kaniko_image
    KANIKO_CONFIG_MAP    = kubernetes_config_map_v1.kaniko.metadata[0].name
    APP_NAMESPACE        = "neoversity"
    APP_URL              = "http://django-app.neoversity.svc.cluster.local"
  }
  depends_on = [helm_release.secrets]
}
module "argocd" {
  source           = "../../modules/argo_cd"
  namespace        = kubernetes_namespace_v1.platform["argocd"].metadata[0].name
  app_namespace    = "neoversity"
  gitops_repo      = var.gitops_repo
  gitops_branch    = "main"
  rds_endpoint     = local.infra.rds_host
  chart_version    = "10.18.0"
  enable_auto_sync = var.enable_application_sync
  enable_pruning   = var.enable_application_pruning
  helm_values = {
    image             = { repository = local.infra.ecr_url }
    externalSecrets   = { enabled = true, rdsSecretArn = local.infra.app_secret_arn, djangoSecretArn = local.infra.django_secret_arn }
    databaseBootstrap = { enabled = var.enable_database_bootstrap, adminSecretArn = local.infra.rds_secret_arn }
    networkPolicy     = { enabled = true, databaseCidrs = local.infra.private_cidrs }
  }
  depends_on = [helm_release.secrets, kubernetes_namespace_v1.app]
}
resource "helm_release" "metrics" {
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"
  wait       = true
}
resource "helm_release" "monitoring" {
  name       = "monitoring"
  namespace  = kubernetes_namespace_v1.platform["monitoring"].metadata[0].name
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "93.3.0"
  values     = [file("${path.module}/../../monitoring/kube-prometheus-stack-values.yaml")]
  timeout    = 1200
  wait       = true
}
resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = "neoversity-top-dashboard"
    namespace = kubernetes_namespace_v1.platform["monitoring"].metadata[0].name
    labels    = { grafana_dashboard = "1" }
  }
  data = { "neoversity-devops.json" = file("${path.module}/../../monitoring/dashboards/neoversity-devops.json") }
}
