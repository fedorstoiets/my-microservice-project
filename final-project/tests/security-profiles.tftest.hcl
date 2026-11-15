# All provider calls mocked at plan time. Never reads the configured production backend.
mock_provider "aws" {
  override_during = plan
  mock_data "aws_caller_identity" { defaults = { account_id = "000000000000" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_rds_engine_version" { defaults = { version_actual = "18.6", parameter_group_family = "postgres18" } }
  mock_data "aws_eks_cluster" {
    defaults = { endpoint = "https://offline.invalid", certificate_authority = [{ data = "b2ZmbGluZQ==" }] }
  }
  mock_data "aws_iam_openid_connect_provider" {
    defaults = { url = "offline.invalid/oidc", client_id_list = ["sts.amazonaws.com"] }
  }
  mock_resource "aws_db_instance" {
    defaults = { master_user_secret = [{ secret_arn = "arn:aws:secretsmanager:us-east-2:000000000000:secret:fixture-master", kms_key_id = "offline", secret_status = "active" }] }
  }
  mock_resource "aws_kms_key" { defaults = { arn = "arn:aws:kms:us-east-2:000000000000:key/00000000-0000-0000-0000-000000000000" } }
}
mock_provider "aws" {
  alias           = "legacy5"
  override_during = plan
  mock_data "aws_partition" { defaults = { partition = "aws" } }
}
mock_provider "aws" {
  alias           = "legacy7"
  override_during = plan
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "000000000000" } }
  mock_resource "aws_eks_cluster" {
    defaults = { vpc_config = { cluster_security_group_id = "sg-offlinefixture" }, identity = [{ oidc = [{ issuer = "https://offline.invalid/oidc" }] }] }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
run "hardened_source" {
  command = plan
  variables { private_runner_verified = true }
  assert {
    condition     = !module.eks.security_configuration.public_endpoint && length(module.eks.security_configuration.public_cidrs) == 0
    error_message = "Hardened API must be private-only."
  }
  assert {
    condition     = module.ecr.tag_mutability == "IMMUTABLE" && alltrue([for auto_ip in module.vpc.public_subnet_auto_ipv4 : !auto_ip])
    error_message = "Hardened repositories/subnets must not permit tag replacement or auto public addresses."
  }
  assert {
    condition     = length(aws_kms_key.eks_security) == 1 && length(module.eks.security_configuration.encryption) == 1
    error_message = "Hardened source requires an explicit retained EKS key."
  }
}
run "continuity_is_explicit" {
  command = plan
  variables { security_profile = "continuity" }
  assert {
    condition     = module.eks.security_configuration.public_endpoint && contains(module.eks.security_configuration.public_cidrs, "0.0.0.0/0") && module.ecr.tag_mutability == "MUTABLE"
    error_message = "Ownership continuity must preserve recorded network/ECR settings until separately approved hardening."
  }
  assert {
    condition     = length(aws_kms_key.eks_security) == 0 && alltrue(module.vpc.public_subnet_auto_ipv4)
    error_message = "Continuity must not silently add encryption resources or alter public-subnet settings."
  }
}
run "private_access_proof_required" {
  command         = plan
  expect_failures = [var.private_runner_verified]
}
run "reviewed_delivery_plan" {
  command = plan
  variables {
    private_runner_verified        = true
    enable_irsa                    = true
    enable_ebs_csi                 = true
    ebs_csi_addon_version          = "v0.0.0-offline-fixture"
    enable_external_secrets        = true
    external_secrets_chart_version = "2.15.0"
    prepare_jenkins_storage        = true
    jenkins_restore_verified       = true
    enable_delivery_v2             = true
    delivery_inputs = {
      ci_tools_image     = "offline.invalid/ci@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
      kaniko_image       = "offline.invalid/kaniko@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      app_secret_arn     = "arn:aws:secretsmanager:us-east-2:000000000000:secret:fixture-app"
      signing_secret_arn = "arn:aws:secretsmanager:us-east-2:000000000000:secret:fixture-signing"
      gitops_secret_arn  = "arn:aws:secretsmanager:us-east-2:000000000000:secret:fixture-gitops"
      kms_key_arns       = []
    }
  }
  assert {
    condition     = length(kubernetes_persistent_volume_claim_v1.jenkins_home) == 1 && kubernetes_storage_class_v1.gp3[0].reclaim_policy == "Retain"
    error_message = "Restored storage must be retained and explicitly referenced."
  }
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.external_secrets_rds[0].policy).Statement[0].Resource, var.delivery_inputs.app_secret_arn)
    error_message = "ESO IAM must include the actual app secret reference used by Argo."
  }
}

run "existing_oidc_is_referenced_not_duplicated" {
  command = plan
  # These cases concern an existing cluster: its issuer/SG identity is already known.
  override_module {
    override_during = plan
    target          = module.eks
    outputs = {
      cluster_name              = "neoversity-lesson-7"
      cluster_security_group_id = "sg-offlinefixture"
      oidc_issuer               = "https://offline.invalid/oidc"
    }
  }
  variables {
    private_runner_verified    = true
    enable_irsa                = true
    existing_oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/offline.invalid/oidc"
  }
  assert {
    condition     = length(aws_iam_openid_connect_provider.eks) == 0
    error_message = "Do not create a duplicate of the verified externally owned provider."
  }
}
run "wrong_oidc_issuer_is_rejected" {
  command = plan
  # These cases concern an existing cluster: its issuer/SG identity is already known.
  override_module {
    override_during = plan
    target          = module.eks
    outputs = {
      cluster_name              = "neoversity-lesson-7"
      cluster_security_group_id = "sg-offlinefixture"
      oidc_issuer               = "https://offline.invalid/oidc"
    }
  }
  variables {
    private_runner_verified    = true
    enable_irsa                = true
    existing_oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/offline.invalid/oidc"
  }
  override_data {
    target          = data.aws_iam_openid_connect_provider.existing[0]
    override_during = plan
    values          = { url = "wrong.invalid/oidc", client_id_list = ["sts.amazonaws.com"] }
  }
  expect_failures = [aws_iam_role.ebs_csi[0], aws_iam_role.kaniko_irsa[0]]
  assert {
    condition     = data.aws_iam_openid_connect_provider.existing[0].url == "wrong.invalid/oidc"
    error_message = "Fixture URL was ${data.aws_iam_openid_connect_provider.existing[0].url}"
  }
  assert {
    condition     = !local.oidc_provider_verified
    error_message = "Fixture verification was ${local.oidc_provider_verified}, expected false"
  }
}
