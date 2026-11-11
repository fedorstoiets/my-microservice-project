#!/usr/bin/env bash
set -euo pipefail
account=$(aws sts get-caller-identity --query Account --output text)
region="${AWS_REGION:-us-east-2}"
cat > backend.hcl <<EOF
bucket = "fedorstoiets-neoversity-tfstate-${account}"
region = "${region}"
EOF
cat > terraform.tfvars <<EOF
aws_region = "${region}"
cluster_name = "neoversity-lesson-7"
node_instance_type = "t3.medium"
EOF
echo "Prepared for account ${account}, region ${region}."
