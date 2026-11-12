locals {
  resolved_engine = var.use_aurora ? (var.engine == "postgres" ? "aurora-postgresql" : "aurora-mysql") : var.engine
  port            = var.engine == "postgres" ? 5432 : 3306

  # AWS supplies version-specific parameter-group family, avoiding manual major-version guesses.
  family = data.aws_rds_engine_version.selected.parameter_group_family

  # Postgres and MySQL do NOT share the same parameter names.
  # MySQL uses general_log and sort_buffer_size instead of log_statement/work_mem.
  db_parameters = merge(
    var.engine == "postgres" ? {
      log_statement = var.parameter_log_statement
      work_mem      = tostring(var.parameter_work_mem_kb)
      } : {
      general_log      = tostring(var.parameter_general_log)
      sort_buffer_size = tostring(var.parameter_sort_buffer_size)
    },
    var.parameter_max_connections == null ? {} : {
      max_connections = tostring(var.parameter_max_connections)
    }
  )
}

data "aws_rds_engine_version" "selected" {
  engine  = local.resolved_engine
  version = var.engine_version
  latest  = true
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.name}-subnets"
  subnet_ids = var.private_subnet_ids
  tags       = merge(var.tags, { Name = "${var.name}-db-subnets" })
}

resource "aws_security_group" "database" {
  name_prefix = "${var.name}-db-"
  description = "Private database access for ${var.name}"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-database" })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_sg" {
  for_each                     = toset(var.allowed_security_group_ids)
  security_group_id            = aws_security_group.database.id
  referenced_security_group_id = each.value
  from_port                    = local.port
  to_port                      = local.port
  ip_protocol                  = "tcp"
  description                  = "Database access from authorized security group"
}

resource "aws_vpc_security_group_ingress_rule" "from_cidr" {
  for_each          = toset(var.allowed_cidr_blocks)
  security_group_id = aws_security_group.database.id
  cidr_ipv4         = each.value
  from_port         = local.port
  to_port           = local.port
  ip_protocol       = "tcp"
  description       = "Database access from authorized CIDR"
}

# No egress rules: the database does not need unrestricted outbound access.
# Security Groups are stateful, allowing responses to established inbound connections.

# Standard RDS has an instance parameter group.
resource "aws_db_parameter_group" "standard" {
  count  = var.use_aurora ? 0 : 1
  name   = "${var.name}-rds-pg"
  family = local.family
  tags   = var.tags

  dynamic "parameter" {
    for_each = local.db_parameters
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = parameter.key == "max_connections" ? "pending-reboot" : "immediate"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora PostgreSQL uses cluster-level tuning for the key coursework parameters.
resource "aws_rds_cluster_parameter_group" "aurora" {
  count  = var.use_aurora ? 1 : 0
  name   = "${var.name}-aurora-pg"
  family = local.family
  tags   = var.tags

  dynamic "parameter" {
    for_each = var.engine == "postgres" ? local.db_parameters : {
      general_log = tostring(var.parameter_general_log)
    }
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = parameter.key == "max_connections" ? "pending-reboot" : "immediate"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Aurora MySQL max_connections and sort_buffer_size are instance-level parameters.
resource "aws_db_parameter_group" "aurora_mysql" {
  count  = var.use_aurora && var.engine == "mysql" ? 1 : 0
  name   = "${var.name}-aurora-instance-pg"
  family = local.family
  tags   = var.tags

  dynamic "parameter" {
    for_each = merge(
      { sort_buffer_size = tostring(var.parameter_sort_buffer_size) },
      var.parameter_max_connections == null ? {} : { max_connections = tostring(var.parameter_max_connections) }
    )
    content {
      name         = parameter.key
      value        = parameter.value
      apply_method = parameter.key == "max_connections" ? "pending-reboot" : "immediate"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
