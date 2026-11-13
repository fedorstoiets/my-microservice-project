#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
# Explicit opt-in: plan database and monitoring together; no apply.
terraform plan -var='deploy_database=true' -var='deploy_monitoring=true' -out=final-infra.tfplan
terraform show -no-color final-infra.tfplan | tail -35
echo 'Review all resource additions, EKS and Helm before terraform apply final-infra.tfplan'
