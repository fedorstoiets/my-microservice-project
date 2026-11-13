variable "aws_region" {
  type        = string
  description = "AWS deployment region"
  default     = "us-east-2"
}
variable "cluster_name" {
  type        = string
  description = "Existing EKS cluster"
  default     = "neoversity-lesson-7"
}
variable "deploy_database" {
  type        = bool
  description = "Opt in to creating a NEW billable RDS database"
  default     = false
}
variable "deploy_monitoring" {
  type        = bool
  description = "Opt in to deploying Helm monitoring stack"
  default     = false
}
variable "database_name" {
  type        = string
  description = "Unique new RDS instance identifier"
  default     = "neoversity-final-db"
}
variable "database_instance_class" {
  type        = string
  description = "Standard RDS instance class"
  default     = "db.t3.micro"
}
variable "database_engine_version" {
  type        = string
  description = "Optional exact PostgreSQL version"
  default     = null
}
variable "db_allowed_security_group_ids" {
  type        = list(string)
  description = "Extra app/worker SGs allowed to reach PostgreSQL"
  default     = []
}
variable "monitoring_chart_version" {
  type        = string
  description = "Optional pinned kube-prometheus-stack chart version; null uses repository default"
  default     = null
}
