# Plan-only offline fixtures. No AWS/Kubernetes/Helm connection is made.
mock_provider "aws" {
  mock_data "aws_eks_cluster" {
    defaults = {
      endpoint              = "https://offline.invalid"
      certificate_authority = [{ data = "b2ZmbGluZS1maXh0dXJl" }]
    }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
run "platform_plan" {
  command = plan
  variables {
    aws_region     = "us-east-2"
    state_bucket   = "offline-fixture"
    ci_tools_image = "offline.invalid/ci@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    kaniko_image   = "offline.invalid/kaniko@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  }
  override_data {
    target = data.terraform_remote_state.infra
    values = {
      outputs = { platform = {
        stack_name        = "goaldevops-v2-offline"
        region            = "us-east-2"
        cluster_name      = "goaldevops-v2-offline"
        rds_host          = "db.offline.invalid"
        rds_secret_arn    = "offline-admin"
        app_secret_arn    = "offline-app"
        django_secret_arn = "offline-signing"
        gitops_secret_arn = "offline-gitops"
        eso_role_arn      = "arn:aws:iam::000000000000:role/offline-eso"
        kaniko_role_arn   = "arn:aws:iam::000000000000:role/offline-builder"
        ecr_url           = "000000000000.dkr.ecr.us-east-2.amazonaws.com/offline"
        private_cidrs     = ["10.80.4.0/24", "10.80.5.0/24", "10.80.6.0/24"]
      } }
    }
  }
  assert {
    condition     = kubernetes_storage_class_v1.gp3.reclaim_policy == "Retain"
    error_message = "Jenkins storage must retain its data."
  }
  assert {
    condition     = kubernetes_service_account_v1.builder.automount_service_account_token == false
    error_message = "The ECR builder must not receive a Kubernetes API token."
  }
}
