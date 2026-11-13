# TOP 1–4 — Additional DevOps Excellence

Four recognizable extras for the Neoversity final project. They **do not replace** the mandatory VPC, EKS, RDS, Jenkins, Argo CD and monitoring work.

## TOP 1 — Post-deployment smoke test

The existing Django `/health/` endpoint executes `SELECT 1` against PostgreSQL and responds with `{ "status": "ok", "connected": true }`. `scripts/smoke-test.sh` checks this JSON and checks that the homepage returns HTTP 2xx.

```bash
bash final-project/scripts/smoke-test.sh
# Alternative with an explicit URL:
BASE_URL=http://127.0.0.1:18080 bash final-project/scripts/smoke-test.sh
```

For local testing use a separate terminal: `kubectl -n neoversity port-forward svc/django-app 18080:80`. A successful test proves *application to database connectivity*; it does not by itself prove that the database is RDS (confirm Django DB host configuration independently).

**Jenkins CI/CD integration:** Add a post-deployment verification stage **after** GitOps commit; wait until Argo CD reports `Synced/Healthy` and the Deployment image matches the committed tag before running smoke tests. Running it immediately after GitOps push is subject to race conditions. Prefer a dedicated lightweight curl/python Kubernetes verification job or call the script from a trusted runner with AWS/kubectl credentials, rather than giving an untrusted build pod broad cluster-admin permissions. A CI stage that cannot reach the service/cluster should not claim success.

## TOP 2 — Dashboard and Prometheus

`monitoring/kube-prometheus-stack-values.yaml` is a small Helm values file for `prometheus-community/kube-prometheus-stack`. `monitoring/dashboard-configmap.yaml` is a Grafana sidecar-discovered dashboard showing:
- Django ready and unavailable replicas
- CPU usage and working-set memory
- PostgreSQL *pod readiness* (not database performance)

After full monitoring deployment (namespaces, storage and EKS resources):

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring -f final-project/monitoring/kube-prometheus-stack-values.yaml
kubectl apply -f final-project/monitoring/dashboard-configmap.yaml
kubectl -n monitoring get deploy,sts,pods
```

The Grafana service for the Helm release above is normally `monitoring-grafana`, not `grafana`:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

Find Grafana's initial admin password from the `monitoring-grafana` Kubernetes Secret in your own environment. Never put it into screenshots, README, ZIP or Git.

Prometheus queries require the relevant kube-state-metrics and kubelet/cAdvisor targets. The preconfigured datasource is usually named `Prometheus`; adjust it if your Helm release uses a different name. An RDS database is not represented by an in-cluster PostgreSQL pod: replace the PostgreSQL readiness panel with AWS/RDS exporter or CloudWatch metrics when migrating to RDS.

## TOP 3 — Terraform security scan

Install [Trivy](https://trivy.dev/latest/getting-started/installation/) in WSL Ubuntu following the official installation instructions. Then:

```bash
bash final-project/scripts/security-scan.sh
STRICT_SECURITY=true bash final-project/scripts/security-scan.sh
```

Reports are written under `final-project/reports/` (exclude from Git). Normal mode **reports findings but does not imply a pass**; strict mode fails on HIGH or CRITICAL findings. Triage and document false positives, don't simply suppress them.

## TOP 4 — One-command verification

After the main final-project Terraform root has been assembled and `terraform init` run:

```bash
bash final-project/scripts/verify-final.sh
```

It checks AWS auth, nodes, Jenkins, Argo CD, image, HPA, monitoring, RDS inventory, application HTTP/database health, Terraform formatting/validation and Trivy if installed. It writes a timestamped report into `final-project/reports/` and exits nonzero if required checks fail. **A RDS inventory is not confirmation of Django using RDS; verify database host/secrets separately.**

### Acceptance evidence

| Extra | Capture evidence |
|---|---|
| TOP 1 | PASS lines from the smoke test and Jenkins post-deploy stage if integrated |
| TOP 2 | Grafana dashboard screenshot plus Prometheus targets status |
| TOP 3 | Trivy report and short remediation notes |
| TOP 4 | `verification-*.txt` report with no failures or skipped mandatory checks |

### Cost / safety

The scripts and dashboard definitions themselves do not create AWS resources. Installing monitoring consumes EKS node CPU/memory; new persistent volumes would incur AWS storage charges. Keep Helm resources managed by one Terraform/Helm owner; do not install the monitoring Helm release manually and separately with Terraform against the same release. Do not destroy Homework #5 remote-state bucket while other states are still using it.
