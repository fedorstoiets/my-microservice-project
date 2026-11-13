# Neoversity DevOps — Final Project Submission

## Overview

A Django microservice deployed to Amazon EKS in `us-east-2`, using a private Amazon RDS PostgreSQL database, Amazon ECR images, Jenkins build/push, Argo CD GitOps delivery, and Prometheus/Grafana monitoring. Provisioning is organized with Terraform modules and isolated state ownership for earlier lessons.

**Source:** https://github.com/fedorstoiets/my-microservice-project/tree/final-project

**Live GitOps chart:** https://github.com/fedorstoiets/neoversity-django-gitops/tree/main/charts/django-app

**AWS region:** `us-east-2` | **EKS cluster:** `neoversity-lesson-7` | **Namespace:** `neoversity` | **Database:** `neoversity-final-db`

## Architecture and deployment flow

`GitHub source (lesson-8-9) → Jenkins (Kubernetes Kaniko build agent) → Amazon ECR → GitOps main (image tag updated) → Argo CD → Amazon EKS (Django Deployment + HPA) → private Amazon RDS PostgreSQL`. Prometheus gathers cluster/container metrics; Grafana provides standard dashboards and a custom Neoversity dashboard.

This final-project folder reuses infrastructure deployed and owned by separate Terraform states (`lesson-5`, `lesson-7`, `lesson-8-9`) and adds RDS plus monitoring under `final-project`. **Do not apply duplicate infrastructure modules from other states.** The bundled `charts/django-app` directory is a reference chart; the **live, authoritative** GitOps chart is in the separate repository linked above. It is the live GitOps `main` values that specify RDS host/user and `django-rds-secrets`.

## Functional evidence

- Jenkins pipeline built the Django container and pushed a commit-derived tag to ECR; a successful previous build was observed.
- Argo CD Application `django-gitops` was `Synced / Healthy`.
- Django had 2/2 available replicas; HPA allowed 2–6 replicas at 70% CPU target.
- RDS PostgreSQL 18.6 was available, private (`publicly_accessible=false`) and encrypted. Django returned `('neoversity_db', 'dbadmin')` from a live database query using the RDS hostname.
- `/health/` returned HTTP 200 with `{"status":"ok","database":"postgresql","connected":true`; homepage returned HTTP 2xx.
- Prometheus returned numeric values for Django ready replicas, HPA desired replicas, CPU, and memory; Grafana sidecar provisioned `Neoversity — Final DevOps / TOP` from a ConfigMap.
- `terraform fmt -check -recursive` and `terraform validate` passed at the final-project root.
- The comprehensive operational verifier reported **PASS=11 FAIL=0 SKIP=0**. See `docs/evidence/verification-summary.txt` and `docs/evidence/smoke-test.txt`.

## Verification (Ubuntu WSL)

```bash
cd ~/Neoversity/my-microservice-project/final-project
bash scripts/smoke-test.sh
bash scripts/verify-final.sh
kubectl -n argocd get application django-gitops
kubectl -n neoversity get deploy,hpa
kubectl -n monitoring get pods
```

The verification script uses AWS CLI credentials; refresh AWS SSO/login first if required. `scripts/security-scan.sh` runs Trivy configuration scanning, but its default non-strict mode does **not** mean zero findings.

## Infrastructure ownership and safe operations

- `lesson-5` Terraform state owns the original VPC/subnets and ECR resources.
- `lesson-7` state owns the existing EKS cluster and application ECR resources.
- `lesson-8-9` state owns Jenkins and Argo CD.
- `final-project` state owns new private RDS and the monitoring Helm release. Use the existing `backend.hcl` and local `*.tfvars` files (ignored by Git) when initializing.
- No credentials, Terraform state, plans, `.env`, or live generated reports should be committed.
- RDS, EKS nodes, NAT gateways, EBS/EFS, and load balancers incur AWS charges until explicitly cleaned up; destroy resources *only from the Terraform state that owns them*.

## Known limitations / mentor-feedback items

- Jenkins currently runs with `persistence.enabled=false`; its home is on an ephemeral `emptyDir`. A private local backup exists but is not included in submission.
- EBS CSI add-on and `gp3` persistent Jenkins PVC have **not** been installed.
- Kaniko uses **EKS Pod Identity**, not IRSA. Account SCP explicitly denied reading IAM OIDC providers, so this substitution must be disclosed rather than labeled IRSA.
- Jenkins JCasC defines a seed job, but GitHub credential lifecycle and private GitOps repository credential declarations are not yet fully codified in IaC.
- The temporary in-cluster PostgreSQL Deployment is retained as a fallback and uses ephemeral storage. Django uses RDS, not that deployment.
- Trivy reported HIGH/CRITICAL IaC findings (including public EKS API endpoint exposure and container security contexts). The passed operational verifier is *not* a strict security approval. See `docs/SECURITY-REVIEW.md` and `docs/evidence/trivy-findings.txt`.
- AWS API endpoint and other permissions must be reviewed before treating this as a production deployment. This is a coursework/lab environment.

## Submission contents

- Terraform source and module definitions in `final-project/`
- Monitoring ConfigMap and dashboard JSON in `monitoring/`
- Smoke test, security scan and consolidated verification scripts in `scripts/`
- Documentation in `docs/` and sanitized test evidence in `docs/evidence/`
- The repository source archive generated from Git `final-project` branch, without credentials/state/reports
