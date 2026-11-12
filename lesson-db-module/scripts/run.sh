#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
usage() {
  cat <<'EOF'
Usage: bash scripts/run.sh <command>
  validate        Prepare, initialize, format-check, Terraform validate, safe plan (no database)
  plan-rds        Plan standard PostgreSQL RDS only (no AWS database created)
  plan-aurora     Plan Aurora PostgreSQL only (no AWS database created)
  plan-mysql      Plan standard MySQL RDS only
  plan-aurora-mysql Plan Aurora MySQL only
  apply-rds       CREATE billable standard PostgreSQL DB (requires CONFIRM_COSTS=yes)
  apply-aurora    CREATE billable Aurora PostgreSQL cluster (requires CONFIRM_COSTS=yes)
  destroy         DESTROY DB resources in current state (requires CONFIRM_DESTROY=yes)

WARNING: Never switch DB modes against a deployed state. Destroy old DB first.
EOF
}
[[ $# -eq 1 ]] || { usage; exit 2; }
cmd="$1"
case "$cmd" in
  validate|plan-rds|plan-aurora|plan-mysql|plan-aurora-mysql|apply-rds|apply-aurora|destroy) ;;
  *) usage; exit 2 ;;
esac
for bin in terraform aws; do command -v "$bin" >/dev/null || { echo "Missing command: $bin" >&2; exit 1; }; done
bash scripts/prepare.sh
terraform init -backend-config=backend.hcl
terraform fmt -recursive
terraform fmt -check -recursive
terraform validate
if [[ "$cmd" == validate ]]; then
  if terraform state list | grep -Eq '^module\.rds\[0\]\.(aws_db_instance|aws_rds_cluster)\.'; then
    echo 'An active database exists in state; safe validation would propose its deletion. Run terraform validate manually instead.' >&2
    exit 3
  fi
  terraform plan -var='deploy_database=false' -out=validate.tfplan
  terraform show -no-color validate.tfplan | tail -20
  echo 'VALIDATED. No database was created.'
  exit 0
fi
if [[ "$cmd" == destroy ]]; then
  [[ "${CONFIRM_DESTROY:-}" == yes ]] || { echo 'Set CONFIRM_DESTROY=yes to acknowledge irreversible data loss.'; exit 2; }
  terraform plan -destroy -out=destroy.tfplan
  terraform show -no-color destroy.tfplan | grep -E 'will be destroyed|Plan:|No changes' || true
  terraform apply destroy.tfplan
  exit 0
fi
case "$cmd" in
  plan-rds|apply-rds) example=examples/rds-postgres.tfvars ;;
  plan-aurora|apply-aurora) example=examples/aurora-postgres.tfvars ;;
  plan-mysql) example=examples/rds-mysql.tfvars ;;
  plan-aurora-mysql) example=examples/aurora-mysql.tfvars ;;
esac
# Don't accidentally plan a mode switch that would destroy a running database.
if terraform state list | grep -Eq '^module\.rds\[0\]\.(aws_db_instance|aws_rds_cluster)\.'; then
  echo 'Database found in this state. Do not change mode. Run destroy first, in the original mode.' >&2
  exit 3
fi
# Verify the remote-state VPC really exists. A stale Terraform output is not sufficient.
if ! [[ -n "${AWS_ACCESS_KEY_ID:-}" ]] && ! aws sts get-caller-identity >/dev/null; then
  echo 'AWS login is expired. Run aws login --remote --region us-east-2, and export credentials for Terraform.' >&2
  exit 1
fi
aws_region="us-east-2"
vpc_id=$(aws ec2 describe-vpcs --region "$aws_region" --filters Name=tag:Name,Values=lesson-5-vpc --query 'Vpcs[0].VpcId' --output text)
if [[ "$vpc_id" == None || -z "$vpc_id" ]]; then
  echo 'Lesson 5 VPC missing. Restore lesson-5 network first, or supply vpc_id and private_subnet_ids and plan manually.' >&2
  exit 1
fi
terraform plan -var-file="$example" -out="${cmd}.tfplan"
terraform show -no-color "${cmd}.tfplan" | grep -E 'will be created|will be destroyed|Plan:' || true
if [[ "$cmd" == apply-* ]]; then
  [[ "${CONFIRM_COSTS:-}" == yes ]] || { echo 'Set CONFIRM_COSTS=yes to deploy a BILLABLE database.' >&2; exit 2; }
  terraform apply "${cmd}.tfplan"
  terraform output
else
  echo 'PLAN ONLY — no database created.'
fi
