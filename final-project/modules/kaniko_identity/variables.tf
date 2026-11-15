variable "cluster_name" { type = string }
variable "namespace" { type = string }
variable "ecr_repository_arn" { type = string }
variable "irsa_role_arn" {
  type    = string
  default = null
}
