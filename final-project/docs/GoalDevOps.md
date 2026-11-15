# GoalDevOps — Neoversity Final DevOps Project v2 acceptance metric

**Status:** Open. Local validation evidence is recorded separately from runtime
success; the matching documentation-review receipt is recorded separately.
An item is complete only after the stated evidence is collected. These repository
gates are not a separately verified instructor grading rubric. The implementation reuses the existing AWS environment. The independent clean
workflow is verified with mocked plans, not a new live deployment. Transferring
39 existing resources or creating a second cluster is not required by the
available assignment/mentor criteria.

## Acceptance gates

- [ ] G01 — `terraform init` succeeds following documented S3/DynamoDB bootstrap.
- [x] G02 — `terraform validate` and `terraform fmt -check -recursive` succeed.
- [ ] G03 — A complete Terraform plan includes VPC, EKS, ECR, RDS, Jenkins, Argo CD, Prometheus and Grafana via connected modules, with no dependency on earlier homework states.
- [ ] G04 — The documented `terraform apply` orchestration deploys the required project infrastructure from a clean environment without manual hidden dependencies.
- [ ] G05 — `kubectl get all -n jenkins` reports healthy workloads and persistent storage.
- [ ] G06 — `kubectl get all -n argocd` and Application status show healthy workloads, `Synced / Healthy`.
- [ ] G07 — `kubectl get all -n monitoring` reports healthy Prometheus and Grafana workloads.
- [ ] G08 — Jenkins is reachable using the documented localhost:8080 port-forward.
- [ ] G09 — Argo CD is reachable using the documented localhost:8081 port-forward.
- [ ] G10 — Grafana is reachable using the documented localhost:3000 port-forward and custom dashboard shows live metrics.
- [ ] G11 — Django connects to private RDS automatically with secure Secrets Manager-backed credential injection; schema migrations run and HTTP/database health succeeds.
- [ ] G12 — Jenkinsfile is in the submitted final-project source; pipeline builds, pushes to ECR, updates GitOps and deploys through Argo CD.
- [ ] G13 — HPA is configured, resource metrics are available, and actual scaling behavior is demonstrated.
- [ ] G14 — Jenkins persistence survives pod replacement, EBS CSI is configured, and IAM/IRSA and JCasC/GitOps credentials have verified least-privilege controls.
- [ ] G15 — Security scan findings are remediated or individually justified, with no unexplained HIGH/CRITICAL issues.
- [ ] G16 — A repeated Terraform plan reveals no unintended drift or replacements.
- [ ] G17 — Controlled destroy works in the documented dependency order; backend state is retained until infrastructure teardown is complete; cleanup evidence exists.
- [x] G18 — README documents architecture, prerequisites, backend bootstrap, apply, CI/CD, port-forwards, verification, troubleshooting and costs/cleanup; current documentation review is recorded.
- [ ] G19 — A clean-environment deployment has been independently tested (or explicitly documented as blocked, not passed).
- [ ] G20 — GitHub branch `final-project` and submission archive `final_DevOps_Стоєцький_Федір.zip` contain matching, audited project sources and evidence.

## Rules

1. Working old lesson deployments are baseline evidence, not proof of clean reproducibility.
2. No Terraform resource may be managed by multiple active states.
3. No apply, import, state removal, or destroy without reviewed plans/state migration procedure.
4. Never put credentials, Terraform state files, live Helm secrets, or Jenkins backups in Git.
5. AWS Organization SCP/OIDC restrictions are blockers to resolve, not exceptions silently waived.
6. Every gate requires an evidence file, terminal verification, or reviewed Git commit before checking it.

## Current remediation evidence

- G02: `docs/evidence/local-validation.json` records the current code fingerprint,
  five Terraform validations, formatting, three local Helm chart lints, fourteen
  mocked plan tests, source/safety regressions and offline Django tests.
- G18: README.md and DEPLOYMENT.md cover the clean submission path;
  MIGRATION-RUNBOOK.md is optional existing-environment reference material.
  The matching receipt is `docs/evidence/documentation-review.json`.
- G15: `docs/evidence/security-summary.json` records the actual strict source
  scan result. The latest source scan passed with no HIGH/CRITICAL findings;
  actual built/deployed-image evidence and advisory dispositions remain required.
- All other unchecked gates require current supporting runtime, ownership or
  publication evidence. Historical snapshots and mock tests do not pass them.
