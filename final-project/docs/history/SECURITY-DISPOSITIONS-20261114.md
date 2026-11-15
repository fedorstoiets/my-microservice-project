# Security dispositions — current source, not live approval

Strict Trivy output is stored privately in `reports/security/`. Sanitized counts
and identifiers are saved in `evidence/security-summary.json` after validation.
The scanner fails on HIGH/CRITICAL findings. Nothing is suppressed globally.
A passed source suite or zero application lockfile CVEs is not an image scan.

## Findings and intended treatment

| Rule | Affected source | Disposition |
|---|---|---|
| AWS-0040 / AWS-0041 | Held EKS public endpoint/open CIDR defaults | Existing network access must survive continuity. New staged EKS is private-only. Resolve private operator access and review a separate existing-cluster endpoint change; CRITICAL remains open. |
| AWS-0039 | Held EKS secrets-encryption configuration | New stage supplies explicit rotating KMS encryption. Verify AWS-managed defaults/live version for existing EKS before a separately reviewed change; HIGH remains open. |
| AWS-0031 | Held ECR mutable tags | New stage uses immutable repositories and full-SHA/digest delivery. Existing IAM/build workflows must be reviewed before changing mutability; HIGH remains open. |
| AWS-0164 | Existing public-subnet auto public IPs | Existing nodes already use private subnets. The new stage disables public-IP auto-assignment; existing settings are retained during migration. Disable auto-assignment in a separate reviewed change where unnecessary; HIGH remains open. |
| AWS-0132 | Legacy backend default SSE-S3 path | Bootstrap accepts a customer KMS key and the new bootstrap creates one. Existing backend encryption requires owner/KMS access and recovery review, not a migration-side replacement; HIGH remains open where legacy default is evaluated. |
| AWS-0038 | Held EKS control-plane logging | New stage enables all control-plane log categories. Existing logging enablement requires a reviewed cost/security plan. |
| AWS-0077 / AWS-0177 | Existing RDS backup/deletion defaults | New environment uses 7-day backups and deletion protection/final snapshot. Do not change existing RDS as part of continuity; separately approve its protection/backup change. |
| AWS-0176 / AWS-0133 | RDS IAM DB authentication/Performance Insights | Password authentication uses Secrets Manager, TLS, private SGs and a non-superuser app role in the new path. IAM DB auth and performance observability are potential future controls; assess overhead/cost and rubric rather than claim they are enabled. |
| AWS-0178 | VPC flow logging | The new stage enables KMS-encrypted 30-day CloudWatch flow logs with scoped delivery IAM and retained audit logs. Existing VPC logging remains unchanged and needs a separate reviewed plan. |
| AWS-0089 | State bucket access logging | Not enabled; CloudTrail/bucket logging availability must be verified and a logging destination reviewed before acceptance. |
| AWS-0024 / AWS-0025 | Backend lock table | New module enables PITR and encryption; bootstrap passes a customer-managed key. Existing table remains owned by lesson-5 and is not changed. |
| AWS-0033 / AWS-0098 | ECR/Secrets Manager encryption | New environment uses a customer-managed rotating key for application secrets and ECR; legacy AES256/AWS-managed paths remain for continuity. |
| DS-0026 | Application and CI Dockerfiles | Kubernetes supplies liveness/readiness/startup checks; Compose supplies healthcheck. CI tools are ephemeral agents rather than network services. No Dockerfile HEALTHCHECK is assumed to prove orchestration health. |
| KSV-01010 | Application ConfigMap | Contains operational database/host configuration, not passwords or signing material. Credentials come only from Secrets. Inspect the rendered manifest privately; do not treat a key-name heuristic as proof of leaked secret values. |
| KSV-0013 | Suspended restore template | Image is intentionally unresolved until a real CI-tools digest exists. render-jenkins-restore.py requires that digest and actual PVC names and supplies the script ConfigMap; raw template must never be deployed. |
| KSV-0020 / KSV-0021 | Restore Job UID/GID 1000 | Matches existing Jenkins ownership for readable restored files. This is a non-root account with dropped capabilities; changing UID would break recovery. |

## Additional controls and open risks

- Production Django requires a signing secret and explicit hosts, uses secure
  cookies, validates RDS certificates and avoids DB-dependent liveness restarts.
  Public TLS/HSTS/CSRF proxy configuration still requires real DNS/certificate
  inputs and an approved rollout. Default access is private ClusterIP.
- Migration/bootstrap pods receive no Kubernetes token. Database bootstrap alone
  receives master credentials; web/migration use a dedicated app role in a fresh
  environment. Existing object ownership/grants require separate database review.
- Signing/app passwords are ephemeral/write-only in Terraform. Projected app DB
  passwords are reread for new connections. Coordinated app-role rotation and
  controller token refresh require reviewed procedures; no automatic rotation
  is falsely claimed for externally issued GitHub tokens.
- Jenkins direct and required transitive plugins are pinned from the official
  update center and checked against chart core. Updates still need scans/testing.
- Kaniko v1.23.2-debug is an archived upstream builder and runs with permissions
  needed for image extraction. Digest pinning prevents tag substitution but does
  not fix vulnerabilities. Scan the actual builder and migrate to a maintained
  compatible builder or obtain an individually reviewed, time-bounded exception.
  Do not give the build service account cluster-admin or database access.
- The CI-tools build updates Debian packages at build time; the published image
  digest and SBOM are required for reproducibility. Its build and image scans are
  currently blocked by the missing Docker daemon and no cloud push authorization.
- NetworkPolicy requires a working enforcement implementation. The fresh infra
  explicitly enables the VPC CNI network-policy agent, but enforcement has not
  been demonstrated. Default-deny tests must be performed after deployment.
- Restore archives reject traversal, links, special files and existing restore
  destinations. Preserve the old backups; successful parsing does not prove
  application consistency or a usable restored controller.

G15 remains open until high/critical dispositions are approved or remediated,
actual image scans pass, and runtime controls are verified. These notes explain
the findings and next actions; they do not accept risk on the user's behalf.
