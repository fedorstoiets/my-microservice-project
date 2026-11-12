resource "kubernetes_service_account_v1" "builder" {
  metadata {
    name      = "kaniko-builder"
    namespace = var.namespace
  }
}

resource "aws_iam_role" "kaniko" {
  name = "neoversity-lesson-89-kaniko-pod-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "pods.eks.amazonaws.com" }
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}
resource "aws_iam_role_policy" "ecr_push" {
  role = aws_iam_role.kaniko.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = ["ecr:BatchCheckLayerAvailability", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart", "ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"], Resource = var.ecr_repository_arn }
    ]
  })
}
resource "aws_eks_addon" "pod_identity" {
  cluster_name                = var.cluster_name
  addon_name                  = "eks-pod-identity-agent"
  resolve_conflicts_on_update = "OVERWRITE"
}
resource "aws_eks_pod_identity_association" "kaniko" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = kubernetes_service_account_v1.builder.metadata[0].name
  role_arn        = aws_iam_role.kaniko.arn
  depends_on      = [aws_eks_addon.pod_identity]
}
