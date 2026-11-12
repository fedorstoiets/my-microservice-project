variable "aws_region" {
  description = "AWS region for the database; default matches earlier coursework."
  type        = string
  default     = "us-east-2"
}

variable "deploy_database" {
  description = "Safety guard. False = no billable RDS or Aurora resources."
  type        = bool
  default     = false
}

variable "use_aurora" {
  description = "False creates one standard RDS instance; true creates Aurora cluster + writer."
  type        = bool
  default     = false
}

variable "engine" {
  description = "Database engine: postgres or mysql. Mapped to aurora-postgresql or aurora-mysql automatically."
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "engine must be postgres or mysql."
  }
}

variable "engine_version" {
  description = "Optional exact/partial engine version; null selects latest available AWS engine version. Pin for production."
  type        = string
  default     = null
}

variable "instance_class" {
  description = "DB instance class: e.g. db.t4g.medium. Aurora engine/version must support it."
  type        = string
  default     = "db.t4g.medium"
}

variable "multi_az" {
  description = "True for Multi-AZ standard RDS. Aurora spans AZs at the storage layer; managed writer count controlled separately."
  type        = bool
  default     = false
}

variable "aurora_instance_count" {
  description = "Number of Aurora instances, including writer. 1 default to limit lab cost; 2+ for higher availability."
  type        = number
  default     = 1
  validation {
    condition     = var.aurora_instance_count >= 1 && var.aurora_instance_count <= 5 && floor(var.aurora_instance_count) == var.aurora_instance_count
    error_message = "aurora_instance_count must be integer 1..5."
  }
}

variable "name" {
  description = "Unique short name, used in tags, resource names and DB identifiers."
  type        = string
  default     = "neoversity-db-lab"
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,35}$", var.name)) && !endswith(var.name, "-") && !strcontains(var.name, "--")
    error_message = "name must be 3..36 lowercase alphanumeric/hyphen chars, start with letter, not end in hyphen or contain double hyphen."
  }
}

variable "db_name" {
  description = "Initial database name. Use letters, numbers or underscores, starting with a letter."
  type        = string
  default     = "appdb"
  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must be 1..63 alphanumeric/underscore characters, starting with a letter."
  }
}

variable "master_username" {
  description = "Master login name. Password generated and stored in AWS Secrets Manager, not Terraform state."
  type        = string
  default     = "dbadmin"
}

variable "vpc_id" {
  description = "Optional VPC ID override; when null read Homework 5 remote state."
  type        = string
  default     = null
}

variable "private_subnet_ids" {
  description = "Optional private subnet ID list override; when null read Homework 5 remote state. Minimum 2 subnets in different AZs."
  type        = list(string)
  default     = null
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to connect to DB. Empty by default = no ingress."
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "Explicit CIDR access list. Default empty; avoid 0.0.0.0/0."
  type        = list(string)
  default     = []
  validation {
    condition     = !contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "Public 0.0.0.0/0 database access is prohibited in this lab module."
  }
}

variable "allocated_storage" {
  description = "Allocated GiB for standard RDS. Not used for Aurora managed storage."
  type        = number
  default     = 20
}

variable "backup_retention_period" {
  description = "Automatic backup retention days; 1 default for coursework (production usually 7+)."
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Prevent accidental deletion (enable in production; disable for paid lab teardown)."
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Lab teardown: true skips final snapshot. Set false for real data."
  type        = bool
  default     = true
}

variable "apply_immediately" {
  description = "True for lab, false for controlled production maintenance windows."
  type        = bool
  default     = true
}

variable "parameter_max_connections" {
  description = "max_connections: null preserves AWS default (recommended for small instances)."
  type        = number
  default     = null
}

variable "parameter_log_statement" {
  description = "PostgreSQL log_statement: none, ddl, mod or all; ignored for MySQL."
  type        = string
  default     = "ddl"
  validation {
    condition     = contains(["none", "ddl", "mod", "all"], var.parameter_log_statement)
    error_message = "parameter_log_statement must be none, ddl, mod, or all."
  }
}

variable "parameter_work_mem_kb" {
  description = "PostgreSQL work_mem in KiB; ignored for MySQL."
  type        = number
  default     = 4096
}

variable "parameter_general_log" {
  description = "MySQL general_log (0 disabled, 1 enabled); ignored for PostgreSQL."
  type        = number
  default     = 0
}

variable "parameter_sort_buffer_size" {
  description = "MySQL sort_buffer_size in bytes; ignored for PostgreSQL."
  type        = number
  default     = 262144
}

variable "tags" {
  description = "Additional tags applied to resources."
  type        = map(string)
  default = {
    Project   = "Neoversity"
    Homework  = "lesson-db-module"
    ManagedBy = "Terraform"
  }
}
