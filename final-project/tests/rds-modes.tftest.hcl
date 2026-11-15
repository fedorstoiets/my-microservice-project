# Mentor's four RDS modes: offline parameter placement, not live deployment proof.
mock_provider "aws" {
  mock_data "aws_rds_engine_version" {
    defaults = { version_actual = "0.0-offline", parameter_group_family = "offline-family" }
  }
}
variables {
  name               = "offline-rds-matrix"
  vpc_id             = "vpc-offline"
  private_subnet_ids = ["subnet-offline-a", "subnet-offline-b"]
  db_name            = "coursework"
}
run "standard_postgresql" {
  command = plan
  module { source = "./modules/rds" }
  variables { engine = "postgres" }
  assert {
    condition     = toset([for p in aws_db_parameter_group.standard[0].parameter : p.name]) == toset(["max_connections", "log_statement", "work_mem"]) && output.db_name == "coursework" && output.port == 5432
    error_message = "Standard PostgreSQL needs instance-level PostgreSQL parameters and the database-name output."
  }
}
run "standard_mysql" {
  command = plan
  module { source = "./modules/rds" }
  variables { engine = "mysql" }
  assert {
    condition     = toset([for p in aws_db_parameter_group.standard[0].parameter : p.name]) == toset(["max_connections", "general_log", "sort_buffer_size"]) && output.port == 3306
    error_message = "Standard MySQL must not receive PostgreSQL parameter names."
  }
}
run "aurora_postgresql" {
  command = plan
  module { source = "./modules/rds" }
  variables {
    engine     = "postgres"
    use_aurora = true
  }
  assert {
    condition     = toset([for p in aws_db_parameter_group.aurora_postgresql[0].parameter : p.name]) == toset(["max_connections", "log_statement", "work_mem"]) && length(aws_rds_cluster_parameter_group.aurora[0].parameter) == 0 && aws_rds_cluster_instance.aurora[0].db_parameter_group_name == aws_db_parameter_group.aurora_postgresql[0].name && output.resolved_engine == "aurora-postgresql"
    error_message = "Aurora PostgreSQL instance tuning must be attached to the actual DB instances, separately from intrinsic cluster settings."
  }
}
run "aurora_mysql" {
  command = plan
  module { source = "./modules/rds" }
  variables {
    engine     = "mysql"
    use_aurora = true
  }
  assert {
    condition     = length(aws_rds_cluster_parameter_group.aurora[0].parameter) == 0 && toset([for p in aws_db_parameter_group.aurora_mysql[0].parameter : p.name]) == toset(["general_log", "max_connections", "sort_buffer_size"]) && alltrue([for p in aws_db_parameter_group.aurora_mysql[0].parameter : p.apply_method == "immediate"]) && aws_rds_cluster_instance.aurora[0].db_parameter_group_name == aws_db_parameter_group.aurora_mysql[0].name && output.resolved_engine == "aurora-mysql"
    error_message = "Aurora MySQL's general_log and dynamic connection/buffer settings require its attached instance group."
  }
}
