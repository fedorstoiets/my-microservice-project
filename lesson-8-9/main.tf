variable "aws_region" {
  type = string
  default = "us-east-2"
}
variable "github_source_repo" {
  type = string
  default = "https://github.com/fedorstoiets/my-microservice-project.git"
}
variable "github_gitops_repo" {
  type = string
  default = "https://github.com/fedorstoiets/neoversity-django-gitops.git"
}
variable "gitops_branch" {
  type = string
  default = "main"
}
variable "ecr_repository_name" {
  type = string
  default = "lesson-7-django"
}
variable "cluster_name" {
  type = string
  default = "neoversity-lesson-7"
}
variable "image_tag" {
  type = string
  default = "lesson-7"
}

provider "aws" { region = var.aws_region }
data "aws_caller_identity" "current" {}
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

resource "kubernetes_namespace_v1" "jenkins" { metadata { name = "jenkins" } }
resource "kubernetes_namespace_v1" "argocd" { metadata { name = "argocd" } }

module "kaniko_identity" {
  source                  = "./modules/kaniko_identity"
  cluster_name            = var.cluster_name
  ecr_repository_arn      = data.aws_ecr_repository.existing.arn
  namespace               = kubernetes_namespace_v1.jenkins.metadata[0].name
}

module "jenkins" {
  source             = "./modules/jenkins"
  namespace          = kubernetes_namespace_v1.jenkins.metadata[0].name
  source_repo        = var.github_source_repo
  service_account    = module.kaniko_identity.service_account_name
}

module "argo_cd" {
  source           = "./modules/argo_cd"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  app_namespace    = "neoversity"
  gitops_repo      = var.github_gitops_repo
  gitops_branch    = var.gitops_branch
  depends_on       = [module.jenkins]
}
