variable "namespace" { type = string }
variable "app_namespace" { type = string }
variable "gitops_repo" { type = string }
variable "gitops_branch" { type = string }

variable "rds_endpoint" { type = string }

variable "chart_version" {
  type    = string
  default = null
}
variable "helm_values" {
  type    = any
  default = {}
}

variable "values_override" {
  description = "Private deployed Helm values for a migration continuity plan; null uses reviewed source values."
  type        = list(string)
  sensitive   = true
  default     = null
}

variable "applications_values_override" {
  type      = list(string)
  sensitive = true
  default   = null
}

variable "enable_auto_sync" {
  type    = bool
  default = false
}

variable "enable_pruning" {
  type    = bool
  default = false
}
