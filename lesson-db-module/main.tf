provider "aws" {
  region = var.aws_region
}

# The database module intentionally reuses the networking created in Lesson 5.
# Remote-state lookup is disabled for a code-only run (deploy_database=false).
data "terraform_remote_state" "lesson5" {
  count   = var.deploy_database && (var.vpc_id == null || var.private_subnet_ids == null) ? 1 : 0
  backend = "s3"
  config = {
    bucket       = "fedorstoiets-neoversity-tfstate-227281812993"
    key          = "lesson-5/terraform.tfstate"
    region       = var.aws_region
    encrypt      = true
    use_lockfile = true
  }
}

locals {
  selected_vpc_id = var.vpc_id != null ? var.vpc_id : (
    var.deploy_database ? data.terraform_remote_state.lesson5[0].outputs.vpc_id : ""
  )

  selected_private_subnets = var.private_subnet_ids != null ? var.private_subnet_ids : (
    var.deploy_database ? data.terraform_remote_state.lesson5[0].outputs.private_subnet_ids : []
  )
}

module "rds" {
  source = "./modules/rds"
  count  = var.deploy_database ? 1 : 0

  name                       = var.name
  use_aurora                 = var.use_aurora
  engine                     = var.engine
  engine_version             = var.engine_version
  instance_class             = var.instance_class
  multi_az                   = var.multi_az
  aurora_instance_count      = var.aurora_instance_count
  db_name                    = var.db_name
  master_username            = var.master_username
  vpc_id                     = local.selected_vpc_id
  private_subnet_ids         = local.selected_private_subnets
  allowed_security_group_ids = var.allowed_security_group_ids
  allowed_cidr_blocks        = var.allowed_cidr_blocks
  allocated_storage          = var.allocated_storage
  backup_retention_period    = var.backup_retention_period
  deletion_protection        = var.deletion_protection
  skip_final_snapshot        = var.skip_final_snapshot
  apply_immediately          = var.apply_immediately
  parameter_max_connections  = var.parameter_max_connections
  parameter_log_statement    = var.parameter_log_statement
  parameter_work_mem_kb      = var.parameter_work_mem_kb
  parameter_general_log      = var.parameter_general_log
  parameter_sort_buffer_size = var.parameter_sort_buffer_size
  tags                       = var.tags
}
