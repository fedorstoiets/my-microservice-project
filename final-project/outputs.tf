output "cluster_name" { value = module.eks.cluster_name }
output "vpc_id" { value = module.vpc.vpc_id }
output "ecr_repository_url" { value = module.ecr.repository_url }
output "rds_endpoint" { value = var.deploy_database ? module.rds[0].endpoint : null }
output "jenkins_service" { value = "jenkins.jenkins.svc.cluster.local:8080" }
output "argocd_service" { value = "argocd-server.argocd.svc.cluster.local:443" }

output "argocd_password_command" {
  value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
}

output "existing_eks_cluster" {
  value = module.eks.cluster_name
}

output "existing_vpc_id" {
  value = module.vpc.vpc_id
}

output "grafana_port_forward" {
  value = "kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
}

output "new_rds_db_name" {
  value = var.deploy_database ? module.rds[0].db_name : null
}

output "new_rds_endpoint" {
  value = var.deploy_database ? module.rds[0].endpoint : null
}

output "new_rds_port" {
  value = var.deploy_database ? module.rds[0].port : null
}

output "new_rds_secret_arn" {
  value = var.deploy_database ? module.rds[0].master_secret_arn : null
}

output "private_subnets" {
  value = module.vpc.private_subnet_ids
}
