output "cluster_name" { value = aws_eks_cluster.main.name }
output "cluster_id" { value = aws_eks_cluster.main.id }
output "cluster_endpoint" { value = aws_eks_cluster.main.endpoint }
output "node_group_name" { value = aws_eks_node_group.main.node_group_name }

output "cluster_security_group_id" {
  value = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}
output "oidc_issuer" { value = aws_eks_cluster.main.identity[0].oidc[0].issuer }

output "security_configuration" {
  value = {
    public_endpoint = aws_eks_cluster.main.vpc_config[0].endpoint_public_access
    public_cidrs    = aws_eks_cluster.main.vpc_config[0].public_access_cidrs
    encryption      = aws_eks_cluster.main.encryption_config
  }
}
