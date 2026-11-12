output "jenkins_service" { value = "jenkins.jenkins.svc.cluster.local:8080" }
output "argocd_service" { value = "argocd-server.argocd.svc.cluster.local:443" }
output "kaniko_role_arn" { value = module.kaniko_identity.role_arn }
output "ecr_repository_url" { value = data.aws_ecr_repository.existing.repository_url }
output "cluster_name" { value = var.cluster_name }
