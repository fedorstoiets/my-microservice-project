variable "name" {
  description = "Resource name prefix, unique per deployment."
  type        = string
}
variable "use_aurora" {
  description = "True: Aurora writer cluster. False: standard RDS."
  type        = bool
  default     = false
}
variable "engine" {
  description = "Logical database engine: postgres or mysql."
  type        = string
  default     = "postgres"
  validation {
    condition     = contains(["postgres", "mysql"], var.engine)
    error_message = "engine must be postgres or mysql."
  }
}
variable "engine_version" {
  description = "Optional AWS engine version; null = latest available. Pin for production."
  type        = string
  default     = null
}
variable "instance_class" {
  description = "RDS/Aurora instance class, e.g. db.t4g.medium."
  type        = string
  default     = "db.t4g.medium"
}
variable "multi_az" {
  description = "Standard RDS Multi-AZ toggle (Aurora has separate storage redundancy)."
  type        = bool
  default     = false
}
variable "aurora_instance_count" {
  description = "Number of Aurora cluster instances; the first acts as writer."
  type        = number
  default     = 1
  validation {
    condition     = var.aurora_instance_count >= 1 && floor(var.aurora_instance_count) == var.aurora_instance_count
    error_message = "aurora_instance_count must be a positive integer."
  }
}
variable "db_name" {
  description = "Initial DB schema/database name."
  type        = string
  default     = "appdb"
}
variable "master_username" {
  description = "DB admin login; password is managed by AWS Secrets Manager."
  type        = string
  default     = "dbadmin"
}
variable "vpc_id" {
  description = "ID of an existing VPC."
  type        = string
}
variable "private_subnet_ids" {
  description = "Existing private subnet IDs, at least 2 across AZs."
  type        = list(string)
  validation {
    condition     = length(var.private_subnet_ids) >= 2
    error_message = "Provide at least two private subnet IDs."
  }
}
variable "allowed_security_group_ids" {
  description = "Only these SGs may connect to the DB port."
  type        = list(string)
  default     = []
}
variable "allowed_cidr_blocks" {
  description = "Explicit authorized CIDR ranges; default none."
  type        = list(string)
  default     = []
  validation {
    condition     = !contains(var.allowed_cidr_blocks, "0.0.0.0/0")
    error_message = "Do not publicly expose the database."
  }
}
variable "allocated_storage" {
  description = "Storage size GiB for standard RDS only."
  type        = number
  default     = 20
}
variable "backup_retention_period" {
  description = "Automatic backups in days."
  type        = number
  default     = 1
  validation {
    condition     = var.backup_retention_period >= 1 && var.backup_retention_period <= 35
    error_message = "Backup retention must be in the range 1..35 days."
  }
}
variable "deletion_protection" {
  description = "Prevent DB deletion while enabled."
  type        = bool
  default     = false
}
variable "skip_final_snapshot" {
  description = "Skip final snapshot on destroy (lab); set false for real data."
  type        = bool
  default     = true
}
variable "apply_immediately" {
  description = "Apply updates immediately, or during maintenance windows."
  type        = bool
  default     = true
}
variable "parameter_max_connections" {
  description = "Optional DB max_connections; null uses AWS default."
  type        = number
  default     = null
}
variable "parameter_log_statement" {
  description = "Postgres log_statement (none/ddl/mod/all)."
  type        = string
  default     = "ddl"
}
variable "parameter_work_mem_kb" {
  description = "Postgres work_mem KiB."
  type        = number
  default     = 4096
}
variable "parameter_general_log" {
  description = "MySQL general_log (0/1)."
  type        = number
  default     = 0
}
variable "parameter_sort_buffer_size" {
  description = "MySQL sort_buffer_size bytes."
  type        = number
  default     = 262144
}
variable "tags" {
  description = "AWS tags."
  type        = map(string)
  default     = {}
}
