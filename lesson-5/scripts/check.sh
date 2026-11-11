#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive
terraform validate
printf 'Terraform formatting and validation checks passed.\n'
