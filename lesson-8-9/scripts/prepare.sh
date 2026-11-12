#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cp -n backend.hcl.example backend.hcl
aws sts get-caller-identity --query Account --output text
aws eks describe-cluster --region us-east-2 --name neoversity-lesson-7 --query cluster.status --output text
aws eks update-kubeconfig --region us-east-2 --name neoversity-lesson-7
kubectl get nodes
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=deploy.tfplan
