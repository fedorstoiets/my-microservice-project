#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
echo 'This deletes CI/CD add-ons, not the existing EKS/VPC/ECR or lesson-7 Django secret.'
read -r -p 'Proceed? type YES: ' answer
[[ "$answer" == YES ]] || exit 1
# Terraform destroys Argo Application helm release first, then Argo, Jenkins and IAM.
terraform plan -destroy -out=cleanup.tfplan
terraform show -no-color cleanup.tfplan | tail -35
read -r -p 'Apply destroy plan? type YES: ' second
[[ "$second" == YES ]] || exit 1
terraform apply cleanup.tfplan
