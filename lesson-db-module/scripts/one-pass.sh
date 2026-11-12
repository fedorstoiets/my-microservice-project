#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
[[ "$(git branch --show-current)" == "lesson-db-module" ]] || { echo 'Please switch to Git branch lesson-db-module first.' >&2; exit 2; }
cd lesson-db-module

# AWS CLI login and short-lived credentials for Terraform S3 backend.
if ! aws sts get-caller-identity >/dev/null 2>&1; then
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE AWS_SECURITY_TOKEN || true
  aws login --remote --region us-east-2
fi
eval "$(aws configure export-credentials --format env)"

bash scripts/run.sh validate
bash scripts/run.sh plan-rds
bash scripts/run.sh plan-aurora
bash scripts/run.sh plan-mysql
bash scripts/run.sh plan-aurora-mysql

cd ..
git add lesson-db-module
if git diff --cached --name-only | grep -E '(^|/)(backend\.hcl|terraform\.tfvars|.*\.tfstate.*|.*\.tfplan|.*\.key|.*\.pem)$'; then
  echo 'Sensitive/private files staged; refusing to commit.' >&2
  exit 1
fi
if ! git diff --cached --quiet; then
  git commit -m 'Add reusable Terraform RDS and Aurora database module'
fi
git push -u origin lesson-db-module

OUT="/mnt/c/Users/Vladi/Downloads/lesson-db-module_Стоєцький_Федір.zip"
if [[ -d /mnt/c/Users/Vladi/Downloads ]]; then
  git archive --format=zip --output="$OUT" HEAD lesson-db-module
  printf '\nSubmission ready:\n- Git branch: https://github.com/fedorstoiets/my-microservice-project/tree/lesson-db-module\n- ZIP: %s\n' "$OUT"
else
  echo 'Windows Downloads folder not found; create ZIP manually with git archive.'
fi
