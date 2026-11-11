#!/usr/bin/env bash
set -euo pipefail
terraform fmt -check -recursive
terraform validate
helm lint charts/django-app --set image.repository=example.invalid/django
helm template django-app charts/django-app --set image.repository=example.invalid/django >/dev/null
echo 'Terraform and Helm local checks passed.'
