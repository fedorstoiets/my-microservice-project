variable "cluster_name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_ids" { type = list(string) }
variable "public_subnet_ids" { type = list(string) }
variable "node_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "kubernetes_version" {
  type    = string
  default = null
}
variable "endpoint_public_access" {
  type    = bool
  default = false
}
variable "public_access_cidrs" {
  type    = list(string)
  default = []
}
variable "enabled_cluster_log_types" {
  type    = list(string)
  default = []
}
variable "secrets_kms_key_arn" {
  type    = string
  default = null
}
variable "harden_nodes" {
  type    = bool
  default = false
}
