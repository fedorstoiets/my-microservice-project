output "service_account_name" { value = kubernetes_service_account_v1.builder.metadata[0].name }
output "role_arn" { value = aws_iam_role.kaniko.arn }
