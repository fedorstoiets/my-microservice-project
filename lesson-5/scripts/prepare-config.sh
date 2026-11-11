#!/usr/bin/env bash
set -euo pipefail

command -v aws >/dev/null || { echo 'AWS CLI is required.' >&2; exit 1; }
account_id=$(aws sts get-caller-identity --query Account --output text)
[[ "$account_id" =~ ^[0-9]{12}$ ]] || { echo 'Cannot determine AWS account ID.' >&2; exit 1; }
region="${AWS_REGION:-us-east-2}"
bucket="fedorstoiets-neoversity-tfstate-${account_id}"
cat > backend.hcl <<EOF
bucket = "${bucket}"
region = "${region}"
EOF
cat > terraform.tfvars <<EOF
aws_region          = "${region}"
bucket_name         = "${bucket}"
table_name          = "terraform-locks"
nat_gateway_enabled = true
EOF
printf 'Prepared backend.hcl and terraform.tfvars for account %s in %s.\n' "$account_id" "$region"
printf 'Review both files before applying. They are ignored by Git.\n'
