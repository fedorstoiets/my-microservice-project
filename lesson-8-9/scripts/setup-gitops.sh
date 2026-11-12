#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
command -v gh >/dev/null || { echo 'Install GitHub CLI (gh) and run gh auth login.'; exit 1; }
gh auth status
if gh repo view fedorstoiets/neoversity-django-gitops >/dev/null 2>&1; then
  echo 'GitOps repo already exists. No overwrite.'; exit 0
fi
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp -a lesson-8-9/gitops-repo/. "$TMP/"
cd "$TMP"
git init -b main
git add .
git -c user.name='Fedor Stoietskyi' -c user.email='fstoiets@bu.edu' commit -m 'Initialize Django GitOps chart'
gh repo create fedorstoiets/neoversity-django-gitops --public --source=. --remote=origin --push
