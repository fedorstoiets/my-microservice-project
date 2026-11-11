#!/usr/bin/env bash
set -euo pipefail
echo 'Destroying Helm LoadBalancer before EKS, to avoid orphaned AWS resources.'
helm uninstall django-app -n neoversity || true
helm uninstall metrics-server -n kube-system || true
kubectl -n neoversity delete secret django-app-secrets --ignore-not-found
# Wait until LB has been deprovisioned; verify console before EKS destroy.
echo 'Check EC2 > Load Balancers for deletion; then run terraform destroy in lesson-7.'
