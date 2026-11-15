# GoalDevOps v2 unified infrastructure configuration.
# MIGRATION HOLD: The remote state has NOT been consolidated.
# DO NOT RUN apply/destroy against this configuration before reviewed state migration.
# Fresh environments use deployments/infra then deployments/platform. This root is the held migration target.
# AWS provider configurations are declared in providers.tf (legacy aliases preserve original tags).

data "aws_eks_cluster" "existing" { name = var.cluster_name }
data "aws_ecr_repository" "existing" { name = var.ecr_repository_name }

provider "kubernetes" {
  host                   = data.aws_eks_cluster.existing.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", var.cluster_name]
  }
}
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.existing.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.existing.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--region", var.aws_region, "--cluster-name", var.cluster_name]
    }
  }
}

module "vpc" {
  providers                      = { aws = aws.legacy5 }
  source                         = "./modules/vpc"
  vpc_cidr_block                 = "10.0.0.0/16"
  public_subnets                 = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets                = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones             = [for az in ["a", "b", "c"] : "${var.aws_region}${az}"]
  vpc_name                       = "lesson-5-vpc"
  nat_gateway_enabled            = true
  public_subnet_auto_assign_ipv4 = var.security_profile == "continuity"
}

module "eks" {
  providers              = { aws = aws.legacy7 }
  source                 = "./modules/eks"
  cluster_name           = var.cluster_name
  vpc_id                 = module.vpc.vpc_id
  subnet_ids             = module.vpc.private_subnet_ids
  public_subnet_ids      = module.vpc.public_subnet_ids
  node_instance_type     = "t3.medium"
  endpoint_public_access = var.security_profile == "continuity"
  public_access_cidrs    = var.security_profile == "continuity" ? ["0.0.0.0/0"] : []
  secrets_kms_key_arn    = var.security_profile == "hardened" ? aws_kms_key.eks_security[0].arn : null

  enable_ebs_csi        = var.enable_ebs_csi
  ebs_csi_addon_version = var.ebs_csi_addon_version
  ebs_csi_role_arn      = var.enable_ebs_csi && var.enable_irsa ? aws_iam_role.ebs_csi[0].arn : null
}

module "ecr" {
  providers      = { aws = aws.legacy7 }
  source         = "./modules/ecr"
  ecr_name       = var.ecr_repository_name
  scan_on_push   = true
  immutable_tags = var.security_profile == "hardened"
}

resource "kubernetes_namespace_v1" "jenkins" {
  metadata { name = "jenkins" }
}
resource "kubernetes_namespace_v1" "argocd" {
  metadata { name = "argocd" }
}

module "kaniko_identity" {
  source             = "./modules/kaniko_identity"
  cluster_name       = module.eks.cluster_name
  ecr_repository_arn = "arn:aws:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
  namespace          = kubernetes_namespace_v1.jenkins.metadata[0].name

  irsa_role_arn = var.enable_irsa ? aws_iam_role.kaniko_irsa[0].arn : null
}
data "aws_caller_identity" "current" {}

module "jenkins" {
  source                  = "./modules/jenkins"
  namespace               = kubernetes_namespace_v1.jenkins.metadata[0].name
  source_repo             = var.github_source_repo
  chart_version           = "5.12.0"
  values_override         = var.continuity_jenkins_values
  service_account         = module.kaniko_identity.service_account_name
  persistence_enabled     = var.enable_delivery_v2
  existing_claim          = var.enable_delivery_v2 ? kubernetes_persistent_volume_claim_v1.jenkins_home[0].metadata[0].name : ""
  existing_claim_sub_path = var.enable_delivery_v2 ? "restored" : ""
  build_config = var.enable_delivery_v2 ? {
    ECR_URL              = module.ecr.repository_url, AWS_REGION = var.aws_region, GITOPS_REPO = var.github_gitops_repo,
    GITOPS_REVIEWED_BASE = local.delivery_metadata.reviewed_gitops_base,
    CI_TOOLS_IMAGE       = local.delivery_metadata.ci_tools_image, KANIKO_IMAGE = local.delivery_metadata.kaniko_image,
    KANIKO_CONFIG_MAP    = kubernetes_config_map_v1.delivery_kaniko[0].metadata[0].name,
    APP_NAMESPACE        = "neoversity", APP_URL = "http://django-app.neoversity.svc.cluster.local"
  } : {}
  depends_on = [helm_release.delivery_secrets]
}

module "argo_cd" {
  source                       = "./modules/argo_cd"
  namespace                    = kubernetes_namespace_v1.argocd.metadata[0].name
  app_namespace                = "neoversity"
  gitops_repo                  = var.github_gitops_repo
  chart_version                = "10.18.0"
  values_override              = var.continuity_argocd_values
  applications_values_override = var.continuity_applications_values
  enable_auto_sync             = var.enable_application_sync
  enable_pruning               = var.enable_application_pruning
  helm_values = {
    image             = { repository = module.ecr.repository_url }
    externalSecrets   = { enabled = var.enable_delivery_v2, rdsSecretArn = local.delivery_metadata.app_secret_arn, djangoSecretArn = local.delivery_metadata.signing_secret_arn }
    databaseBootstrap = { enabled = var.enable_database_bootstrap, adminSecretArn = module.rds[0].master_secret_arn }
    networkPolicy     = { enabled = false, databaseCidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"] }
  }
  gitops_branch = "main"
  depends_on    = [module.jenkins]
  rds_endpoint  = var.deploy_database ? module.rds[0].endpoint : null
}

module "rds" {
  # Preserves original module address module.rds[0] in the target state.
  count              = var.deploy_database ? 1 : 0
  source             = "./modules/rds"
  name               = "neoversity-final-db"
  use_aurora         = false
  engine             = "postgres"
  engine_version     = var.database_engine_version
  instance_class     = "db.t3.micro"
  multi_az           = false
  db_name            = "neoversity_db"
  master_username    = "dbadmin"
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  allowed_security_group_ids = concat(
    [module.eks.cluster_security_group_id], var.db_allowed_security_group_ids
  )
  allowed_cidr_blocks       = []
  parameter_max_connections = 100
  parameter_log_statement   = "ddl"
  parameter_work_mem_kb     = 4096
  backup_retention_period   = 1
  deletion_protection       = false
  skip_final_snapshot       = true
  tags                      = { Project = "Neoversity-Final", ManagedBy = "Terraform", Environment = "lab" }
}

resource "helm_release" "monitoring" {
  count            = var.deploy_monitoring ? 1 : 0
  name             = "monitoring"
  namespace        = "monitoring"
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = var.monitoring_chart_version
  values           = var.continuity_monitoring_values != null ? var.continuity_monitoring_values : [file("${path.module}/monitoring/kube-prometheus-stack-values.yaml")]
  timeout          = 1200
  wait             = true
}
