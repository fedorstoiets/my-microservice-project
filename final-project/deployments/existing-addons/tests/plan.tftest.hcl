# Offline plan fixtures only. Never use fixture provider identifiers for deployment.
mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_eks_cluster" {
    defaults = {
      name                  = "neoversity-lesson-7"
      endpoint              = "https://offline.invalid"
      certificate_authority = [{ data = "b2ZmbGluZQ==" }]
      identity              = [{ oidc = [{ issuer = "https://offline.invalid/oidc" }] }]
    }
  }
  mock_data "aws_iam_openid_connect_provider" {
    defaults = { url = "offline.invalid/oidc", client_id_list = ["sts.amazonaws.com"] }
  }
}
mock_provider "kubernetes" {}
mock_provider "helm" {}
variables {
  existing_oidc_provider_arn = "arn:aws:iam::000000000000:oidc-provider/offline.invalid/oidc"
  ebs_csi_addon_version      = "v0.0.0-eksbuild.0"
}
run "additive_storage_plan" {
  command = plan
  assert {
    condition     = kubernetes_storage_class_v1.gp3.reclaim_policy == "Retain" && kubernetes_storage_class_v1.gp3.parameters["encrypted"] == "true"
    error_message = "Existing Jenkins preparation must retain and encrypt storage."
  }
  assert {
    condition     = kubernetes_persistent_volume_claim_v1.jenkins[0].metadata[0].namespace == "jenkins" && kubernetes_persistent_volume_claim_v1.jenkins[0].wait_until_bound == false
    error_message = "Prepare a separate claim without waiting for or restarting the existing controller."
  }
  assert {
    condition     = length(helm_release.eso) == 0 && length(aws_iam_openid_connect_provider.eks) == 0
    error_message = "Do not create an OIDC provider or install ESO without explicit inputs."
  }
}
run "wrong_issuer_blocks_all_roles" {
  command = plan
  override_data {
    target = data.aws_iam_openid_connect_provider.existing[0]
    values = { url = "wrong.invalid/oidc", client_id_list = ["sts.amazonaws.com"] }
  }
  expect_failures = [aws_iam_role.workload["ebs"], aws_iam_role.workload["builder"], aws_iam_role.workload["eso"]]
  assert {
    condition     = !local.verified
    error_message = "A different cluster issuer must fail verification."
  }
}
