data "aws_caller_identity" "flow" { count = var.enable_flow_logs ? 1 : 0 }
data "aws_region" "flow" { count = var.enable_flow_logs ? 1 : 0 }
data "aws_partition" "flow" { count = var.enable_flow_logs ? 1 : 0 }
resource "aws_cloudwatch_log_group" "flow" {
  count             = var.enable_flow_logs ? 1 : 0
  name              = "/goaldevops/${var.vpc_name}/vpc-flow"
  retention_in_days = 30
  kms_key_id        = var.flow_logs_kms_key_arn
  skip_destroy      = true
}
resource "aws_iam_role" "flow" {
  count = var.enable_flow_logs ? 1 : 0
  name  = "${var.vpc_name}-flow-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole",
    Condition = {
      StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.flow[0].account_id },
      ArnLike      = { "aws:SourceArn" = "arn:${data.aws_partition.flow[0].partition}:ec2:${data.aws_region.flow[0].region}:${data.aws_caller_identity.flow[0].account_id}:vpc-flow-log/*" }
    }
  }] })
}
resource "aws_iam_role_policy" "flow" {
  count = var.enable_flow_logs ? 1 : 0
  role  = aws_iam_role.flow[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.flow[0].arn}:*" },
    { Effect = "Allow", Action = "logs:DescribeLogGroups", Resource = "*" }
  ] })
}
resource "aws_flow_log" "main" {
  count                = var.enable_flow_logs ? 1 : 0
  vpc_id               = aws_vpc.main.id
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow[0].arn
  iam_role_arn         = aws_iam_role.flow[0].arn
  traffic_type         = "ALL"
  depends_on           = [aws_iam_role_policy.flow]
}
