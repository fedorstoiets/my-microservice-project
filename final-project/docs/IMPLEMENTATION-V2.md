# GoalDevOps v2 — current implementation status

**Migration HOLD remains active.** Source remediation is implemented; no live
state transfer, apply, destroy, import, IAM update, deployment, database change,
commit or push has been performed. Do not infer runtime acceptance from syntax,
mocked plans, historical lesson deployments, or successful local scans.

## Implemented source paths

- The held root preserves existing RDS/monitoring addresses, backend key,
  provider aliases and legacy ownership. Private continuity values can preserve
  deployed Helm configuration during a separately approved ownership transfer.
- `bootstrap/` defines protected KMS-encrypted/versioned/private S3 and protected
  PITR/encrypted legacy DynamoDB locking. Existing backend ownership is unchanged.
- `deployments/infra/` and `deployments/platform/` implement a distinct new
  environment with staged providers, separate state keys and required verified
  version inputs. They do not adopt or share existing lesson resources.
- Fresh infrastructure includes private EKS, logs/KMS/IMDS hardening, immutable
  ECR, private RDS, app/signing secrets through ephemeral/write-only arguments,
  scoped IRSA, EBS CSI and VPC CNI network-policy configuration.
- Platform includes retained/protected Jenkins storage, managed ESO secret store
  and repository credentials, Jenkins/JCasC/plugins, Argo health ordering,
  metrics-server, monitoring/dashboard and read-only delivery RBAC.
- Django uses production guards, static files, TLS RDS, separate liveness and
  schema/database readiness, with app-role bootstrap and ordered migration Jobs.
- CI uses exact SCM revisions, immutable image reuse/build and scans, preserving
  GitOps chart alignment, and expected revision/image/health verification.
- Offline tests, strict security scans, state/continuity/backup safety helpers,
  runtime evidence collection and deterministic draft/final packaging exist.

## Remaining acceptance blockers

AWS credentials are currently unavailable. Historical snapshots show 39 proposed
transfers and no duplicate ownership candidates, but fresh state/object-version
checks are required. SCP/OIDC permissions and private-runner access remain
unverified. The Docker daemon is unavailable, blocking actual image build tests.
No CI-tools image digest, issued GitHub token provisioning, real Jenkins restore,
Argo rollout, database bootstrap/migration, HPA scaling or disposable teardown
has been verified. Security findings in held legacy settings and Kaniko image
risk require reviewed remediation/disposition. The official external rubric is
still missing. See REQUIREMENTS-MAP.md and REMEDIATION-REPORT.md.

## Operations

README.md documents local validation and port-forwards. DEPLOYMENT.md documents
the new-environment path, storage cutover, secrets, CI/CD, troubleshooting, cost
and controlled cleanup. MIGRATION-RUNBOOK.md provides preflight, the historical
address map, continuity isolation, operator approval packet and rollback.
MIGRATION-HOLD.md is unchanged and remains authoritative. No generic planning
helper enables live migration or deployment.

Current priority review and exact phase approvals: EXECUTION-PLAN.md.
Security source closure versus runtime/image limitations: SECURITY-DISPOSITIONS.md.
Exact acceptance artifacts and minimum work: ACCEPTANCE-EVIDENCE.md.
