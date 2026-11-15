#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
echo 'GoalDevOps source checks (NO LIVE APPLY; providers must already be initialized)'
terraform fmt -check -recursive
for root in . bootstrap deployments/infra deployments/platform deployments/existing-addons; do
  terraform -chdir="$root" validate -no-color
done
helm lint charts/django-app --strict --set config.POSTGRES_HOST=example.invalid
helm lint modules/argo_cd/charts/applications --strict --set rdsEndpoint=example.invalid
helm lint charts/platform-secrets --strict --set gitopsSecretArn=example-gitops --set gitopsRepo=https://example.invalid/repo.git
terraform test -no-color
terraform -chdir=deployments/infra test -no-color
terraform -chdir=deployments/platform test -no-color
terraform -chdir=deployments/existing-addons test -no-color
"${PYTHON:-python3}" scripts/test-source.py
DJANGO_LOCAL_DEVELOPMENT=1 "${PYTHON:-python3}" Django/manage.py test core --noinput
printf '%s\n' 'Source checks passed; AWS runtime G01–G20 remain independently gated.'
