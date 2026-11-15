# Desired in-place security changes only; never execute before ownership continuity and reviewed approval.
# Associating EKS encryption is a one-way change: continuity must not remove it after execution.
resource "aws_kms_key" "eks_security" {
  count                   = var.security_profile == "hardened" ? 1 : 0
  description             = "GoalDevOps EKS secrets; retain for cluster and recovery lifetime"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  lifecycle { prevent_destroy = true }
}
