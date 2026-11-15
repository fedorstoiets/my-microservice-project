# Neoversity DevOps final-project submission

> **November 15, 2026 verification update:** See [CI Build #17 acceptance](CI-BUILD-17-ACCEPTANCE.md). Earlier CI status rows are historical; the successful Replay does not establish complete SCM-to-GitOps deployment.

The implementation targets the existing account `227281812993`, region
`us-east-2`, EKS `neoversity-lesson-7`. Migration HOLD is active. No second cluster,
39-resource transfer, live apply, Jenkins restart, SQL or GitOps rollout was
performed by this implementation. Runtime observations below are timestamped
baseline evidence, not proof this source revision is deployed. No grade is claimed.

## Evidence by grading category

| Category | Supported evidence | Remaining verification |
|---|---|---|
| Infrastructure architecture — 20 | Complete VPC/EKS/ECR/RDS/Jenkins/Argo/monitoring modules; independent bootstrap→infra→platform workflow with no homework remote states; five validated roots and 14 mocked plans, including four RDS modes. Existing-addons implements missing prerequisites without owning old resources. | Live clean bootstrap is simulated, not demonstrated. Additive existing-cluster plan/apply needs SCP/actual OIDC inputs and explicit approval. |
| Security — 20 | Strict source scan: 0 CRITICAL/0 HIGH; exact IRSA issuer/audience/subjects, scoped secret/KMS permissions, non-root app, TLS/role separation, protected storage. AWS metadata corrected Aurora MySQL instance parameter placement. | OIDC discovery is SCP-denied. Existing image scan/digest relationship, actual IRSA/ESO/secret reconciliation and current DB least-privilege/TLS proof remain open. Source scan is not deployed-image safety. |
| Deployment and CI/CD — 30 | Submitted Jenkinsfile checks out exact SCM revision, tests, strictly scans IaC/dependencies/rendered manifests, builds/scans ECR digest, publishes GitOps and verifies exact Argo/image/DB health. CI Bash dependency fixed. Existing app HTTP health reports PostgreSQL connected and Argo is Synced/Healthy. | A successful final-project build is still required; old lesson-8-9 builds are not substituted. Jenkins API access was denied; images are unbuilt here because Docker daemon is unavailable. Publishing/deployment require explicit scope. |
| Monitoring and HPA — 20 | Existing Prometheus: 19/19 targets up; live Django CPU/memory and HPA desired replicas returned numeric values. HPA: CPU metric valid, current/desired 2, CPU utilization 3%. Custom five-panel Grafana dashboard ConfigMap is provisioned. | Controlled load scaling/recovery, Grafana authenticated UI evidence and Jenkins persistence replacement-survival have not been performed. |
| Documentation — 10 | README, exact deployment examples, existing-owner/additive boundaries, CI/CD, RDS/secrets, verification, costs and recovery/cleanup precautions. Source/archive manifest and checksum validation. | Original instructor rubric/message is unavailable beyond the versioned repository's mentor-feedback summary. GitHub final publication and final acceptance remain open. |

## Evidence files

- `evidence/local-validation.json`: actual source fingerprint and successful local suite.
- `evidence/security-summary.json`: actual strict source results; exceptions remain separate.
- `evidence/runtime-implementation.json`: observed image reference and container imageID,
  ECR tag digest, GitOps revision, RDS/HTTP, dashboard, Prometheus/HPA metadata.
- `evidence/rds-mode-metadata.json`: AWS parameter metadata and official scope references;
  four engine/mode tests are plans, not four deployed databases.
- `evidence/jenkins-backup-check.json`: 79 files restored locally with zero hash mismatches;
  required keys present, no plugin binaries in that old archive. Application consistency,
  Jenkins boot and credential decryption are not proven.
- `evidence/documentation-review.json`: documentation coverage/hash review, not live success.

The deployed tag `fea9e0c3973a` resolves to ECR digest
`sha256:fd3deed1868090c735b5a810c668934bcdbb52e633b0641c8b77125881aab6e7`;
containers report imageID
`sha256:57c93b7fa8f4735160b9da71a0ca4c41071f010721050fa4f8b1e0ec7a6b5def`.
Their relation may be index/platform manifests; it was not verified because later
AWS profile credential export failed. They must not be silently treated as equal
or labeled malicious tag drift without manifest evidence. Argo revision observed:
`43a3a1b0b4d9129b3512d89bdf74d27089537862`. The current source was not deployed.

## Mentor items and submission contents

The [versioned mentor-feedback summary](https://github.com/fedorstoiets/my-microservice-project/blob/ef1eea3976651bbf96a3306a77f7b0ddd741e8ff/final-project/README.md#mentor-feedback-to-close-before-submission)
asks for four RDS mode plans/parameters, persistent Jenkins/CSI, IRSA where required,
JCasC/Kubernetes-backed GitHub credentials, Argo private-repository access, RDS
injection/migrations and a successful build from final-project. The source covers
those implementations; the open runtime requirements above are not checked off.

The source archive includes Terraform/modules, charts, Django/Dockerfiles,
Jenkinsfile, scripts, examples and sanitized evidence. Live credentials, tfvars,
state/plans, Jenkins backups, caches and private reports are excluded. Source
publication must preserve the current remote branch head and unrelated files.
Use the ZIP's MANIFEST.json for its exact committed source revision and draft/
acceptance status; a candidate archive is not proof of all G01–G20 passing.
