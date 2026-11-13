#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
aws sts get-caller-identity --output json
aws eks describe-cluster --name neoversity-lesson-7 --region us-east-2 --query 'cluster.status' --output text
kubectl get nodes
for r in lesson-5 lesson-7 lesson-8-9; do echo "State owner: $r"; done
echo 'No AWS changes made.'
