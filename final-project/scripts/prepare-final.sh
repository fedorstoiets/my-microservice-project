#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
command -v terraform >/dev/null
command -v aws >/dev/null
aws sts get-caller-identity --query Account --output text
if [[ ! -f backend.hcl ]]; then cp backend.hcl.example backend.hcl; fi
terraform init -backend-config=backend.hcl -input=false
terraform fmt -recursive
terraform validate
terraform plan -var='deploy_database=false' -var='deploy_monitoring=false' -out=safe.tfplan
printf '\nSafe plan ready: safe.tfplan; nothing has been applied.\n'
