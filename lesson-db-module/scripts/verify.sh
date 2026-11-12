#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform output
id=$(terraform output -raw database_identifier)
region="${AWS_REGION:-us-east-2}"
if aws rds describe-db-clusters --region "$region" --db-cluster-identifier "$id" --query 'DBClusters[0].[Status,Engine,Endpoint]' --output table 2>/dev/null; then
  exit 0
fi
aws rds describe-db-instances --region "$region" --db-instance-identifier "$id" --query 'DBInstances[0].[DBInstanceStatus,Engine,Endpoint.Address]' --output table
