# Additive resources only. Existing VPC/EKS/ECR/RDS/Jenkins/Argo remain with their owners.
# MIGRATION HOLD: no state transfer or apply is authorized by this source.
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws        = { source = "hashicorp/aws", version = "~> 6.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.30" }
    helm       = { source = "hashicorp/helm", version = "~> 3.0" }
  }
  backend "s3" {
    key          = "goaldevops-v2/existing-addons.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = ["227281812993"]
}
data "aws_partition" "current" {}
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
data "aws_iam_openid_connect_provider" "existing" {
  count = var.existing_oidc_provider_arn == null ? 0 : 1
  arn   = var.existing_oidc_provider_arn
}
resource "aws_iam_openid_connect_provider" "eks" {
  count          = var.create_oidc_provider ? 1 : 0
  url            = data.aws_eks_cluster.existing.identity[0].oidc[0].issuer
  client_id_list = ["sts.amazonaws.com"]
}
locals {
  issuer = replace(data.aws_eks_cluster.existing.identity[0].oidc[0].issuer, "https://", "")
  provider_arn = var.existing_oidc_provider_arn != null ? var.existing_oidc_provider_arn : (
    var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : null
  )
  verified = var.existing_oidc_provider_arn == null ? var.create_oidc_provider && var.oidc_absence_verified : (
    replace(data.aws_iam_openid_connect_provider.existing[0].url, "https://", "") == local.issuer &&
    contains(data.aws_iam_openid_connect_provider.existing[0].client_id_list, "sts.amazonaws.com")
  )
  subjects = {
    ebs     = { suffix = "ebs-csi-irsa", subject = "system:serviceaccount:kube-system:ebs-csi-controller-sa" }
    builder = { suffix = "kaniko-irsa", subject = "system:serviceaccount:jenkins:kaniko-builder" }
    eso     = { suffix = "external-secrets-irsa", subject = "system:serviceaccount:external-secrets:external-secrets" }
  }
}
resource "aws_iam_role" "workload" {
  for_each = local.subjects
  name     = "${var.cluster_name}-${each.value.suffix}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity",
    Principal = { Federated = local.provider_arn },
    Condition = { StringEquals = {
      "${local.issuer}:aud" = "sts.amazonaws.com", "${local.issuer}:sub" = each.value.subject
    } }
  }] })
  lifecycle {
    precondition {
      condition     = local.verified
      error_message = "Verified OIDC ownership, issuer and STS audience are required before any IRSA role is created."
    }
  }
}
resource "aws_iam_role_policy_attachment" "ebs" {
  role       = aws_iam_role.workload["ebs"].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
resource "aws_iam_role_policy" "builder" {
  role = aws_iam_role.workload["builder"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
    { Effect = "Allow", Resource = data.aws_ecr_repository.existing.arn,
    Action = ["ecr:DescribeImages", "ecr:BatchCheckLayerAvailability", "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"] }
  ] })
}
resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = data.aws_eks_cluster.existing.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = aws_iam_role.workload["ebs"].arn
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
  count = var.prepare_jenkins_storage ? 1 : 0
  metadata {
    name      = "jenkins-home"
    namespace = "jenkins"
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class_v1.gp3.metadata[0].name
    resources { requests = { storage = "8Gi" } }
  }
  wait_until_bound = false
  lifecycle { prevent_destroy = true }
}
resource "aws_iam_role_policy" "eso" {
  count = var.enable_eso ? 1 : 0
  role  = aws_iam_role.workload["eso"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat([
    { Effect = "Allow", Action = ["secretsmanager:DescribeSecret", "secretsmanager:GetSecretValue"], Resource = var.secret_arns }
    ], length(var.kms_key_arns) == 0 ? [] : [
    { Effect = "Allow", Action = "kms:Decrypt", Resource = var.kms_key_arns,
    Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com" } } }
  ]) })
}
resource "helm_release" "eso" {
  count            = var.enable_eso ? 1 : 0
  name             = "external-secrets"
  namespace        = "external-secrets"
  create_namespace = true
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "2.15.0"
  wait             = true
  timeout          = 900
  values = [yamlencode({ serviceAccount = {
    create      = true, name = "external-secrets",
    annotations = { "eks.amazonaws.com/role-arn" = aws_iam_role.workload["eso"].arn }
  } })]
  depends_on = [aws_iam_role_policy.eso]
}
output "integration" {
  value = {
    cluster_name     = data.aws_eks_cluster.existing.name
    builder_role_arn = aws_iam_role.workload["builder"].arn
    eso_role_arn     = aws_iam_role.workload["eso"].arn
    jenkins_claim    = var.prepare_jenkins_storage ? kubernetes_persistent_volume_claim_v1.jenkins[0].metadata[0].name : null
  }
}
