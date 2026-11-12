#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
for bin in aws kubectl helm terraform git gh; do command -v "$bin" || { echo "Missing: $bin"; exit 1; }; done
aws sts get-caller-identity --query Account --output text
kubectl get nodes
if ! gh repo view fedorstoiets/neoversity-django-gitops >/dev/null 2>&1; then
  echo 'Missing public GitOps repository. Create with scripts/setup-gitops.sh first.' >&2; exit 1
fi
if ! kubectl -n neoversity get secret django-app-secrets >/dev/null 2>&1; then
  echo 'Missing existing Django secret from lesson-7. Recreate per lesson-7 README.' >&2; exit 1
fi
