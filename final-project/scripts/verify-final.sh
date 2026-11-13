#!/usr/bin/env bash
# TOP 4 — Final-project verification; read-only except optional smoke-test HTTP GET.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="${REPORT_DIR:-$ROOT/reports}"
mkdir -p "$REPORT_DIR"
REPORT="$REPORT_DIR/verification-$(date -u +%Y%m%dT%H%M%SZ).txt"
exec > >(tee -a "$REPORT") 2>&1
ok=0; failed=0; skipped=0
pass(){ echo "PASS: $*"; ok=$((ok+1)); }
fail(){ echo "FAIL: $*"; failed=$((failed+1)); }
skip(){ echo "SKIP: $*"; skipped=$((skipped+1)); }
step(){ echo; echo "===== $* ====="; }
required(){ command -v "$1" >/dev/null 2>&1 || { fail "Missing command: $1"; return 1; }; }
AWS_REGION="${AWS_REGION:-us-east-2}"
EKS_CLUSTER="${EKS_CLUSTER:-neoversity-lesson-7}"
APP_NS="${APP_NS:-neoversity}"
step 'Tools and AWS identity'
required aws; required kubectl; required python3
if command -v terraform >/dev/null 2>&1; then
  terraform -version | head -1
else skip 'Terraform CLI unavailable'; fi
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json && pass 'AWS credentials valid' || fail 'AWS credentials expired/unavailable'
step 'EKS nodes / namespaces'
if kubectl cluster-info >/dev/null 2>&1; then
  kubectl get nodes; kubectl get namespaces
  pass 'Kubernetes API accessible'
else
  fail "Kubernetes API not available; run aws eks update-kubeconfig --name $EKS_CLUSTER --region $AWS_REGION"
fi
step 'CI/CD'
if kubectl -n jenkins rollout status statefulset/jenkins --timeout=20s; then pass 'Jenkins controller ready'; else fail 'Jenkins controller not ready'; fi
if kubectl -n argocd get application django-gitops -o json > "$REPORT_DIR/argocd-application.json"; then
  python3 - "$REPORT_DIR/argocd-application.json" <<'PY'
import json,sys
app=json.load(open(sys.argv[1]))
s=app.get('status',{}); sync=s.get('sync',{}).get('status'); health=s.get('health',{}).get('status')
print(f'Argo CD: sync={sync}, health={health}')
if sync != 'Synced' or health != 'Healthy': sys.exit(1)
PY
  if [[ $? -eq 0 ]]; then pass 'Argo CD Synced + Healthy'; else fail 'Argo CD not Synced + Healthy'; fi
else fail 'Argo CD application not found'; fi
step 'Application and autoscaling'
if kubectl -n "$APP_NS" rollout status deployment/django-app --timeout=25s; then pass 'Django rollout ready'; else fail 'Django rollout not ready'; fi
kubectl -n "$APP_NS" get deploy,pods,svc,hpa || fail 'Unable to list app resources'
img="$(kubectl -n "$APP_NS" get deploy django-app -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || true)"
if [[ -n "$img" ]]; then echo "Deployed image: $img"; pass 'Deployment image resolved'; else fail 'Deployment image not found'; fi
if kubectl -n "$APP_NS" get hpa django-app >/dev/null 2>&1; then pass 'HPA exists'; else fail 'HPA missing'; fi
step 'Monitoring'
if kubectl -n monitoring get pods >/dev/null 2>&1; then
  kubectl -n monitoring get pods
  if kubectl -n monitoring get deploy,sts -o name 2>/dev/null | grep -Eqi 'prometheus|grafana'; then pass 'Monitoring resources discovered'; else fail 'No Prometheus/Grafana resources found'; fi
else fail 'Monitoring namespace unavailable'; fi
step 'RDS'
if aws rds describe-db-instances --region "$AWS_REGION" --query 'DBInstances[].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Engine:Engine}' --output table; then
  echo 'INFO: List above is an inventory, not proof that Django uses RDS.'
else fail 'RDS inventory request failed'; fi
step 'Django HTTP + DB smoke test'
if [[ "${RUN_SMOKE:-true}" == "true" ]]; then
  if bash "$ROOT/scripts/smoke-test.sh"; then pass 'Django HTTP + DB smoke test'; else fail 'Django HTTP + DB smoke test'; fi
else skip 'Smoke test disabled'; fi
step 'Terraform checks'
if command -v terraform >/dev/null 2>&1 && [[ -f "$ROOT/main.tf" ]]; then
  (cd "$ROOT" && terraform fmt -check -recursive && terraform validate) && pass 'Terraform formatting + validation' || fail 'Terraform formatting/validation (run terraform init first)'
else skip 'Terraform root not assembled yet'; fi
step 'Security scan'
if command -v trivy >/dev/null 2>&1; then
  bash "$ROOT/scripts/security-scan.sh" && pass 'Trivy scan executed (review findings)' || fail 'Trivy failed to run'
else skip 'Trivy not installed'; fi
step 'Summary'
echo "PASS=$ok FAIL=$failed SKIP=$skipped"
echo "Report: $REPORT"
if (( failed > 0 )); then exit 1; fi
if (( skipped > 0 )); then echo 'WARNING: Incomplete verification because some checks were skipped.'; fi
