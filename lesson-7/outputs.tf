output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "cluster_id" { value = module.eks.cluster_id }
output "node_group_name" { value = module.eks.node_group_name }
output "vpc_id" { value = data.terraform_remote_state.lesson5.outputs.vpc_id }
output "ecr_repository_url" { value = module.ecr.repository_url }
