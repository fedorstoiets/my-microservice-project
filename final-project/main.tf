# Adopt-by-reference strategy: lesson-5/lesson-7/lesson-8-9 retain ownership.
# This state ONLY owns new RDS and monitoring resources.
provider "aws" { region = var.aws_region }

data "terraform_remote_state" "lesson5" {
  backend = "s3"
  config = {
    bucket = "fedorstoiets-neoversity-tfstate-227281812993"
    key    = "lesson-5/terraform.tfstate"
    region = var.aws_region
  }
}

data "aws_eks_cluster" "existing" { name = var.cluster_name }

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

module "rds" {
  count              = var.deploy_database ? 1 : 0
  source             = "./modules/rds"
  name               = var.database_name
  use_aurora         = false
  engine             = "postgres"
  engine_version     = var.database_engine_version
  instance_class     = var.database_instance_class
  multi_az           = false
  db_name            = "neoversity_db"
  master_username    = "dbadmin"
  vpc_id             = data.terraform_remote_state.lesson5.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.lesson5.outputs.private_subnet_ids
  allowed_security_group_ids = concat(
    [data.aws_eks_cluster.existing.vpc_config[0].cluster_security_group_id],
    var.db_allowed_security_group_ids
  )
  allowed_cidr_blocks       = []
  parameter_max_connections = 100
  parameter_log_statement   = "ddl"
  parameter_work_mem_kb     = 4096
  backup_retention_period   = 1
  deletion_protection       = false # Lab teardown only; enable for real workloads.
  skip_final_snapshot       = true  # Lab teardown only; enable final snapshot for real workloads.
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
  values           = [file("${path.module}/monitoring/kube-prometheus-stack-values.yaml")]
  timeout          = 1200
  wait             = true
}
