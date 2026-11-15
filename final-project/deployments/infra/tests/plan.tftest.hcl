# All AWS calls mocked. These fixture identifiers are never deployment inputs.
mock_provider "aws" {
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_caller_identity" { defaults = { account_id = "000000000000" } }
  mock_data "aws_availability_zones" { defaults = { names = ["us-east-2a", "us-east-2b", "us-east-2c"] } }
  mock_data "aws_rds_engine_version" {
    defaults = { version_actual = "18.6", parameter_group_family = "postgres18" }
  }
  mock_resource "aws_iam_role" { defaults = { arn = "arn:aws:iam::000000000000:role/offline-fixture" } }
  mock_resource "aws_iam_openid_connect_provider" { defaults = { arn = "arn:aws:iam::000000000000:oidc-provider/offline.invalid" } }
  mock_resource "aws_kms_key" { defaults = { arn = "arn:aws:kms:us-east-2:000000000000:key/00000000-0000-0000-0000-000000000000" } }
  mock_resource "aws_eks_cluster" {
    defaults = {
      identity = [{ oidc = [{ issuer = "https://offline.invalid/oidc" }] }]
    }
  }
}
run "fresh_infrastructure_plan" {
  command = plan
  variables {
    aws_region              = "us-east-2"
    stack_name              = "goaldevops-v2-offline-test"
    kubernetes_version      = "1.37"
    database_engine_version = "18.6"
    ebs_csi_addon_version   = "v0.0.0-offline-fixture"
    vpc_cni_addon_version   = "v0.0.0-offline-fixture"
  }
  assert {
    condition     = module.eks.cluster_name == "goaldevops-v2-offline-test"
    error_message = "Stack name must propagate through the cluster module."
  }
  assert {
    condition     = aws_secretsmanager_secret_version.django.secret_string == null
    error_message = "Signing secret must not use state-persisted secret_string."
  }
}
