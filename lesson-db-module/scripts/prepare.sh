#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f backend.hcl ]]; then
  aws_account="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
  cat > backend.hcl <<EOF
bucket = "fedorstoiets-neoversity-tfstate-${aws_account}"
region = "us-east-2"
EOF
  chmod 600 backend.hcl
fi
if [[ ! -f terraform.tfvars ]]; then
  cp terraform.tfvars.example terraform.tfvars
fi
printf 'Prepared local backend.hcl and terraform.tfvars (not tracked in Git).
'
