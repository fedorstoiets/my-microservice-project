# Explicit EBS CSI provisioning: enable only after the IRSA role can be created.
# The Helm Jenkins chart uses StorageClass gp3 and a persistent PVC.
resource "kubernetes_storage_class_v1" "gp3" {
  count = var.enable_ebs_csi ? 1 : 0
  metadata { name = "gp3" }
  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  reclaim_policy         = "Retain"
  allow_volume_expansion = true
  parameters             = { type = "gp3", encrypted = "true" }
}
variable "enable_ebs_csi" {
  type    = bool
  default = false
  validation {
    condition     = !var.enable_ebs_csi || var.enable_irsa
    error_message = "This EBS CSI configuration requires enable_irsa=true and authorized IAM/OIDC prerequisites."
  }
}
