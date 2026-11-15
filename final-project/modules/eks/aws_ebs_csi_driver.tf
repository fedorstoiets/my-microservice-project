# Requires an existing IAM OIDC provider created by the IRSA prerequisite.
# Disabled until IAM SCP authorization and controlled state migration are complete.
variable "enable_ebs_csi" {
  type    = bool
  default = false
}
variable "ebs_csi_role_arn" {
  type    = string
  default = null
}
resource "aws_eks_addon" "ebs_csi" {
  count                    = var.enable_ebs_csi ? 1 : 0
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_addon_version
  service_account_role_arn = var.ebs_csi_role_arn
}

variable "ebs_csi_addon_version" {
  type    = string
  default = null
}
