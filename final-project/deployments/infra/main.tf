# NEW ENVIRONMENTS ONLY. Not a migration destination for existing lesson resources.
terraform {
  required_version = ">= 1.14.0"
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 6.0" }
    random = { source = "hashicorp/random", version = "~> 3.7" }
  }
  backend "s3" {
    key          = "goaldevops-v2/infra.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
provider "aws" {
  region = var.aws_region
  default_tags { tags = { Project = var.stack_name, ManagedBy = "Terraform" } }
}
data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_availability_zones" "available" { state = "available" }
locals {
  private_cidrs = ["10.80.4.0/24", "10.80.5.0/24", "10.80.6.0/24"]
  issuer        = replace(module.eks.oidc_issuer, "https://", "")
  service_accounts = {
    ebs    = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
    eso    = "system:serviceaccount:external-secrets:external-secrets"
    kaniko = "system:serviceaccount:jenkins:kaniko-builder"
  }
}
module "vpc" {
  source                         = "../../modules/vpc"
  vpc_cidr_block                 = "10.80.0.0/16"
  public_subnets                 = ["10.80.1.0/24", "10.80.2.0/24", "10.80.3.0/24"]
  private_subnets                = local.private_cidrs
  availability_zones             = slice(data.aws_availability_zones.available.names, 0, 3)
  vpc_name                       = var.stack_name
  nat_gateway_enabled            = true
  public_subnet_auto_assign_ipv4 = false
  enable_flow_logs               = true
  flow_logs_kms_key_arn          = aws_kms_key.workloads.arn
}
resource "aws_kms_key" "eks" {
  description             = "${var.stack_name} EKS secrets"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
module "eks" {
  source                    = "../../modules/eks"
  cluster_name              = var.stack_name
  kubernetes_version        = var.kubernetes_version
  vpc_id                    = module.vpc.vpc_id
  subnet_ids                = module.vpc.private_subnet_ids
  public_subnet_ids         = module.vpc.public_subnet_ids
  node_instance_type        = var.node_instance_type
  endpoint_public_access    = false
  public_access_cidrs       = []
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  secrets_kms_key_arn       = aws_kms_key.eks.arn
  harden_nodes              = true
}
resource "aws_iam_openid_connect_provider" "eks" {
  url            = module.eks.oidc_issuer
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "workload" {
  for_each = local.service_accounts
  name     = "${var.stack_name}-${each.key}"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity",
    Principal = { Federated = aws_iam_openid_connect_provider.eks.arn },
    Condition = { StringEquals = {
      "${local.issuer}:aud" = "sts.amazonaws.com", "${local.issuer}:sub" = each.value
    } }
  }] })
}
resource "aws_iam_role_policy_attachment" "ebs" {
  role       = aws_iam_role.workload["ebs"].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
module "ecr" {
  source         = "../../modules/ecr"
  ecr_name       = "${var.stack_name}-django"
  scan_on_push   = true
  immutable_tags = true
  kms_key_arn    = aws_kms_key.workloads.arn
}
resource "aws_ecr_repository" "ci" {
  name                 = "${var.stack_name}-ci-tools"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.workloads.arn
  }
}
module "rds" {
  source                   = "../../modules/rds"
  name                     = "${var.stack_name}-db"
  engine                   = "postgres"
  engine_version           = var.database_engine_version
  instance_class           = var.database_instance_class
  db_name                  = "neoversity_db"
  master_username          = "dbadmin"
  vpc_id                   = module.vpc.vpc_id
  private_subnet_ids       = module.vpc.private_subnet_ids
  named_security_group_ids = { eks = module.eks.cluster_security_group_id }
  backup_retention_period  = 7
  deletion_protection      = true
  skip_final_snapshot      = false
  apply_immediately        = false
  parameter_log_statement  = "none"
}
resource "aws_secretsmanager_secret" "django" {
  name                    = "${var.stack_name}/django-signing"
  kms_key_id              = aws_kms_key.workloads.arn
  recovery_window_in_days = 30
}
ephemeral "random_password" "django" {
  length  = 64
  special = false
}
resource "aws_secretsmanager_secret_version" "django" {
  secret_id                = aws_secretsmanager_secret.django.id
  secret_string_wo         = jsonencode({ secret_key = ephemeral.random_password.django.result })
  secret_string_wo_version = 1
}
resource "aws_secretsmanager_secret" "database_app" {
  name                    = "${var.stack_name}/database-app"
  kms_key_id              = aws_kms_key.workloads.arn
  recovery_window_in_days = 30
}
ephemeral "random_password" "database_app" {
  length  = 48
  special = false
}
resource "aws_secretsmanager_secret_version" "database_app" {
  secret_id                = aws_secretsmanager_secret.database_app.id
  secret_string_wo         = jsonencode({ username = "goaldevops_app", password = ephemeral.random_password.database_app.result })
  secret_string_wo_version = 1
}
# Only metadata is in Terraform for externally issued, fine-grained GitHub tokens.
resource "aws_secretsmanager_secret" "gitops" {
  name                    = "${var.stack_name}/gitops"
  kms_key_id              = aws_kms_key.workloads.arn
  recovery_window_in_days = 30
}
resource "aws_iam_role_policy" "eso" {
  role = aws_iam_role.workload["eso"].name
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect   = "Allow", Action = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"],
    Resource = [aws_secretsmanager_secret.database_app.arn, module.rds.master_secret_arn, aws_secretsmanager_secret.django.arn, aws_secretsmanager_secret.gitops.arn]
  }] })
}
resource "aws_iam_role_policy" "kaniko" {
  role = aws_iam_role.workload["kaniko"].name
  policy = jsonencode({
    Version = "2012-10-17", Statement = [
      { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      { Effect = "Allow", Action = ["ecr:DescribeImages", "ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = "arn:${data.aws_partition.current.partition}:ecr:${var.aws_region}:${data.aws_caller_identity.current.account_id}:repository/${var.stack_name}-django" }
  ] })
}

resource "aws_kms_key" "workloads" {
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "EnableAccountIAM", Effect = "Allow", Principal = { AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root" }, Action = "kms:*", Resource = "*" },
    { Sid = "AllowScopedCloudWatchLogs", Effect = "Allow", Principal = { Service = "logs.${var.aws_region}.amazonaws.com" }, Action = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = "*", Condition = { ArnEquals = { "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/goaldevops/${var.stack_name}/vpc-flow" } } }
  ] })
  description             = "${var.stack_name} application secrets and images"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}
resource "aws_iam_role_policy" "eso_kms" {
  role = aws_iam_role.workload["eso"].name
  policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Action = "kms:Decrypt", Resource = aws_kms_key.workloads.arn,
    Condition = { StringEquals = { "kms:ViaService" = "secretsmanager.${var.aws_region}.amazonaws.com" } }
  }] })
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "vpc-cni"
  addon_version               = var.vpc_cni_addon_version
  configuration_values        = jsonencode({ enableNetworkPolicy = "true" })
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = module.eks.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = aws_iam_role.workload["ebs"].arn
  depends_on               = [module.eks, aws_iam_role_policy_attachment.ebs]
}
