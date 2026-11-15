output "platform" {
  value = {
    stack_name        = var.stack_name
    region            = var.aws_region
    cluster_name      = module.eks.cluster_name
    endpoint          = module.eks.cluster_endpoint
    rds_host          = module.rds.endpoint
    rds_secret_arn    = module.rds.master_secret_arn
    app_secret_arn    = aws_secretsmanager_secret.database_app.arn
    django_secret_arn = aws_secretsmanager_secret.django.arn
    gitops_secret_arn = aws_secretsmanager_secret.gitops.arn
    eso_role_arn      = aws_iam_role.workload["eso"].arn
    kaniko_role_arn   = aws_iam_role.workload["kaniko"].arn
    ecr_url           = module.ecr.repository_url
    ci_ecr_url        = aws_ecr_repository.ci.repository_url
    private_cidrs     = local.private_cidrs
  }
}
