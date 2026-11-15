# Security review — desired source versus actual runtime

The unchanged strict source/configuration/dependency scanner reports **0 CRITICAL
and 0 HIGH** for the desired hardened profile. No `.trivyignore`, ignore-unfixed,
rule exclusion or severity downgrade was introduced. Scanning the explicit
continuity inputs still reports **2 CRITICAL and 5 HIGH**, proving the historical
configuration has not been hidden. Live remediation remains unverified and needs
reviewed plans plus separate authorization. G15 stays open.

## Each original finding

| Finding | Source and resource | Actual relevance and resolution |
|---|---|---|
| AWS-0040 CRITICAL | modules/eks/eks.tf; module.eks.aws_eks_cluster.main | Historical `neoversity-lesson-7` API is public. Hardened default is private-only. Require measured private runner access before proposing the in-place endpoint update; no live change was made. |
| AWS-0041 CRITICAL | same EKS resource | Historical public allowlist is 0.0.0.0/0. Hardened CIDRs are empty with public endpoint disabled. Continuity explicitly preserves the old settings only for ownership transfer. |
| AWS-0031 HIGH | modules/ecr/ecr.tf; module.ecr.aws_ecr_repository.main | Historical lesson-7-django repository is mutable. Desired tags are immutable; CI reuses full-SHA tags and deploys by digest. Actual ECR change requires its own reviewed plan. |
| AWS-0039 HIGH | modules/eks/eks.tf; module.eks.aws_eks_cluster.main | Historical explicit encryption_config is absent, but the recorded Kubernetes version is 1.37. AWS guarantees default envelope encryption for 1.28+; absence of a customer key is not proof of plaintext. Desired source adds an explicit retained, rotating customer key as defense in depth. Association is one-way and needs KMS/recovery review; no key/association was created. |
| AWS-0164 HIGH (1) | modules/vpc/vpc.tf; module.vpc.aws_subnet.public[0] | Historical lesson-5-vpc-public-1 auto-assigns addresses. Desired value is false; nodes already use private subnets. Proposed attribute change affects future ENIs, not existing addresses. |
| AWS-0164 HIGH (2) | same file; module.vpc.aws_subnet.public[1] | Same evidence/treatment for lesson-5-vpc-public-2. |
| AWS-0164 HIGH (3) | same file; module.vpc.aws_subnet.public[2] | Same evidence/treatment for lesson-5-vpc-public-3. |

`evidence/security-findings-ledger.json` records all seven independently, source
locations, historical resource names, desired changes and runtime status. The
historical snapshot is 2026-11-14T20:12:31Z; current authentication failed, so
none is represented as a current live read. AWS's authoritative encryption and
endpoint documentation supports the qualification above:
[default encryption](https://docs.aws.amazon.com/eks/latest/userguide/envelope-encryption.html),
[endpoint controls](https://docs.aws.amazon.com/eks/latest/userguide/config-cluster-endpoint.html),
[ECR immutability](https://docs.aws.amazon.com/AmazonECR/latest/userguide/image-tag-mutability.html).
This is evidence-based classification, not an accepted blanket exception.

## Profiles, migration and rollback

Secure reusable defaults are private API, empty public CIDRs, immutable ECR and
no auto public IPs. The held root defaults to `security_profile=hardened`, with
private-runner proof required before planning and a retained customer key. The
continuity input generator explicitly selects `continuity` and deployed Helm
values. Both profiles are tested with mocked plan-time providers. Changing
source does not authorize either profile's application under HOLD.

Continuity must preserve physical IDs, tags and RDS/Helm ownership without
upgrades. The subsequent security plan may only create the retained key and
update the EKS/ECR/three subnet settings in scope; replacement, import, deletion
or any RDS/Helm mutation is rejected by its allowlist guard. After actual key
association, do not revert to the pre-hardening continuity configuration or
remove the key. Keep the runner/recovery path and a separately reviewed endpoint
break-glass procedure. See EXECUTION-PLAN.md for ordering and real-plan blockers.

## Runtime image findings — newly measured, not suppressed

Read-only registry scans ran without Docker or publishing. Full package/CVE
records are in `evidence/runtime-image-review.json`; private raw JSON remains
in ignored reports. Counts are occurrences, not distinct CVEs.

| Artifact | Measured result | Treatment / remaining proof |
|---|---|---|
| Archived upstream Kaniko v1.23.2-debug | 11 CRITICAL / 228 HIGH | Rejected for new rollout inputs; preserved in history for auditing existing deployments. Do not deploy it for the new path. |
| Verified maintained osscontainertools v1.29.1-debug digest, linux/amd64 | 0 CRITICAL / HIGH, 4 UNKNOWN occurrences / 2 distinct advisories | Source-compatible /kaniko/executor entrypoint and multi-architecture publication verified. Actual ECR/build execution not tested. GO-2026-5932 and CVE-2026-97054 remain unscored and require reachability/fix review; no exemption was invented. |
| Previous Python 3.12-slim digest | 49 HIGH | Deprecated as desired base; includes unfixed distribution findings. Existing images were not changed. |
| New pinned Python 3.12-Alpine base, before build upgrades | 16 HIGH, all krb5-libs with fixed 1.22.3-r0 | Recipes upgrade packages and require that vendor-verified minimum. Locked psycopg/PyYAML musl wheels were verified for amd64/arm64. Actual resulting app/CI images must still be built/scanned. |
| Trivy source image copied from in CI multi-stage build | 6 HIGH in Git/Git template OS packages, plus 2 UNKNOWN in copied binary | Vulnerable Git packages are not copied or run by that stage; only /usr/local/bin/trivy is copied. CI installs vendor-fixed Git >=2.54.1-r0 separately. Copied binary's unscored Go advisories remain visible and need review. |

The package floors and official APK index are recorded in ci/os-security.json.
The latest official Trivy release was verified as v0.76.2; no nonexistent newer
release was invented. The maintained builder's published tag/digest/platforms
were verified from the upstream release and GHCR, not inferred from a tag name.
[Maintained release](https://github.com/osscontainertools/kaniko/releases/tag/v1.29.1)
and [Go advisory](https://vuln.go.dev/ID/GO-2026-5932.json) are primary references.
A module-level OpenPGP advisory is not automatically a proven reachable flaw or
a safe false positive; that requires actual symbol/reachability evidence. Severity
UNKNOWN is not treated as zero risk.

Docker is unavailable. Therefore no patched application/CI image build, SBOM,
full image scan, or runtime ABI/ECR helper test is claimed. Changing a Dockerfile
or scanning the unmodified base is not proof of the resulting image's security.

## Other findings and controls

- Remaining source findings are medium/low and remain in the strict report:
  held EKS logging, RDS protection/backup/IAM-auth/Performance Insights, legacy
  VPC logging, backend access logging and retained AES encryption paths.
  The new environment implements stronger relevant defaults. Existing settings
  still need scoped plan/cost/recovery review; no scanner paths were excluded.
- Dockerfile HEALTHCHECK omissions are intentional: Kubernetes/Compose provide
  probes; CI is an agent, not a network service. Real image/runtime checks remain.
- The application ConfigMap contains operational DB/host settings, not passwords.
  The restored Jenkins job must run UID/GID 1000 to preserve recovered ownership.
  Its raw template is suspended/unresolved; the renderer requires a real digest
  and supplies the script ConfigMap. These are explained findings, not suppressions.
- Existing OIDC references must match issuer/audience. Data postconditions and
  every IRSA role's precondition reject mismatches before role creation; scoped
  subjects, exact secrets/KMS resources and read-only verifier RBAC are retained.
- No web pod gets master credentials or a Kubernetes token. Role bootstrap is
  transactional, refuses privilege/membership/foreign-owner drift, requires safe
  session logging and fails closed if audit/log permissions cannot be satisfied.
- No Jenkins values change may restart an unbacked ephemeral controller. Restore
  attestation gates cutover; Argo/Application values remain frozen during recovery.
  Automatic sync, SQL bootstrap and pruning default off. Legacy PostgreSQL/data
  must be inventoried/retained before any separately approved prune/deletion.
- Source and remote-image reviews are not an authorization to accept residual
  risk or mark G15 complete. See ACCEPTANCE-EVIDENCE.md for remaining evidence.
