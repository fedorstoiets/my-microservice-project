output "existing_eks_cluster" { value = data.aws_eks_cluster.existing.name }
output "existing_vpc_id" { value = data.terraform_remote_state.lesson5.outputs.vpc_id }
output "private_subnets" { value = data.terraform_remote_state.lesson5.outputs.private_subnet_ids }
output "new_rds_endpoint" { value = var.deploy_database ? module.rds[0].endpoint : null }
output "new_rds_port" { value = var.deploy_database ? module.rds[0].port : null }
output "new_rds_db_name" { value = var.deploy_database ? module.rds[0].db_name : null }
output "new_rds_secret_arn" { value = var.deploy_database ? module.rds[0].master_secret_arn : null }
output "grafana_port_forward" { value = "kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80" }
output "argocd_password_command" { value = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" }
