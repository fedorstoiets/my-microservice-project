# Exact GoalDevOps acceptance evidence and minimum remaining work

> **November 15, 2026 verification update:** See [CI Build #17 acceptance](CI-BUILD-17-ACCEPTANCE.md). Earlier CI status rows are historical; the successful Replay does not establish complete SCM-to-GitOps deployment.

Source validation is evidence for source claims only. Neither mocked plans nor
historical lesson success prove a clean deployment or current live health. G02 has local source evidence; G18 has the matching documentation-review receipt.
Other gates remain blocked/unverified for the newly submitted implementation. The official
external Neoversity rubric is still missing and must be compared before a final
submission or numeric grade can be claimed. Existing-environment additions and offline reproducibility follow DEPLOYMENT.md; the existing-resource migration
in EXECUTION-PLAN is optional.

| Gate | Exact source/test evidence | Required runtime/evaluation evidence and minimum action | Current status |
|---|---|---|---|
| G01 | bootstrap/main.tf; five local provider/module caches and lockfiles | Approved distinct bootstrap, current versioning/KMS/locking reads, successful authenticated `terraform init` log with no secrets | Blocked: new backend not deployed/initialized |
| G02 | evidence/local-validation.json code fingerprint; reports/source-check.txt: fmt + 5 validates + 3 lints + mocked plans + unit tests | No live deployment needed; receipt must match current code | Passed source |
| G03 | deployments/infra + platform plans; root security/continuity/cutover mock scenarios | Complete real saved plans + JSON showing all required modules/resources across stages, explicit owners, no unresolved/deferred earlier-homework dependencies; reviewed IDs and source/plan hashes | Blocked: real plans missing |
| G04 | DEPLOYMENT.md / EXECUTION-PLAN P09; infra/platform graph and explicit versions | Actual authorized clean apply logs in order, private runner, versions/quota confirmed, no hidden resource/secret bootstrap dependencies | Blocked: not deployed |
| G05 | Root protected claim/cutover guard, new platform claim, gp3 Retain; persistent_jenkins_ready regression rejects unrelated/unmounted PVC | `kubectl get all -n jenkins`, ready controller that actually mounts a Bound expected PVC/PV; inventory names/UIDs measured | Unverified |
| G06 | Argo chart health/waves, explicit sync opt-in, delivery_ready regressions | Current Application repo/path/revision, Synced/Healthy, successful operation and current healthy Argo workloads | Unverified |
| G07 | Pinned monitoring chart + managed dashboard; monitoring_ready requires both Prometheus and Grafana controllers | Namespace workload list, positive ready Prometheus/Grafana controllers, healthy scrape targets; a single healthy pod is insufficient | Unverified |
| G08 | README Jenkins port-forward, chart ClusterIP service | Current localhost:8080 `/login` HTTP success and UI evidence with no credentials | Unverified |
| G09 | README Argo TLS port-forward, configs.params.server.insecure=false | Current localhost:8081 UI/TLS evidence; compare actual serving-certificate fingerprint and trusted name/CA. Do not use an unverified TLS bypass | Unverified |
| G10 | monitoring/dashboard-configmap.yaml and managed dashboard JSON | localhost:3000 login/UI, labeled dashboard provisioned, timestamped numeric custom metrics and healthy Prometheus targets | Unverified |
| G11 | ESO v1 references, exact ARN IAM/KMS, TLS CA, app/admin separation, guarded transactional bootstrap, -3/-2/-1/0 ordering; chart/DB mock tests | Approved existing schema-role ownership/grant transition if needed, actual secret reconciliation and credential rotation, successful migrations, matching private/encrypted RDS endpoint, verify-full TLS, restricted role and `/health/` schema/DB success | Blocked: secrets/SQL/rollout |
| G12 | Jenkinsfile copies; CLI/YAML regressions; immutable reuse/build/scan; GitOps provenance; DEPLOY=false build-only / true deploy boundary | Real controller declarative validation; actual CI/app image builds/SBOM/scans; successful full-SHA ECR build, approved GitOps commit and exact Argo revision/digest/ready rollout/health | Blocked: Docker/cloud/publishing |
| G13 | HPA min2/max6 CPU70%, resource requests, new metrics-server | Authenticated metrics API reads, controlled approved load on disposable environment, baseline/peak/recovery replica counts and CPU metrics/events/timestamps; HPA presence alone insufficient | Unverified |
| G14 | IRSA exact issuer/audience/subject, external OIDC match guard; EBS/Retain PVC; backup verifier/restore renderer, JCasC credential references, namespace read-only verifier | Resolve actual SCP permissions, verify effective caller and least-privilege allowed/denied actions privately, application-consistent backup + usable recovery, real PVC cutover and approved pod replacement with same PV/home marker/jobs/credentials | Blocked: permissions/recovery |
| G15 | Strict source scan 0 HIGH/CRITICAL, no ignore additions; security-findings-ledger; continuity scan retains 2 CRITICAL/5 HIGH; remote image review | Live hardened state or approved evidence-backed exceptions, actual post-upgrade app/CI images and maintained builder scans; review unscored advisories and remaining medium/low findings; no broad ignore-unfixed | Blocked: runtime/image proof |
| G16 | check-plan.py count/ID/format/import guard, security allowlist, execution packet physical-ID comparison | Repeated complete refreshed plans for actual demo owners with zero unintended drift/replacement after deployment. Existing-owner no-managed-change plans have refresh deltas pending review | Blocked: clean demo/reviewed deltas |
| G17 | Dependency-aware teardown/rollback in P09 and DEPLOYMENT | Approved disposable controlled teardown, backups/final snapshots, retained volumes/KMS/backend handled in order, AWS inventory/cost cleanup proof; do not destroy existing working resources as a test | Blocked: not authorized/tested |
| G18 | README and linked deployment/migration/execution/acceptance documents; evidence/documentation-review.json hashes | Exact topics reviewed: architecture, prerequisites, backend, staged plan/apply review, CI/CD, port-forwards, verification, troubleshooting, costs/cleanup | Passed documentation |
| G19 | Distinct new names/backend keys; staged provider bootstrap and explicit version inputs | Independent operator's fresh-environment deployment log or explicit blocked report. Currently explicitly blocked; not a success checkbox | Blocked |
| G20 | package-submission.py allowlist, deterministic ZIP/manifest/checksum, dirty-branch/all-gates guard | Authorized clean `final-project` commit/push, matching exact source + sanitized evidence and final archive, complete official rubric/screenshots | Blocked: dirty branch/open gates |

## Evidence integrity

Keep exact timestamps, source fingerprint/commit, actual cluster/context/account,
artifact digests and IDs. Record raw private evidence hashes and reviewer/approval
references; omit credentials, state, private plans and backups from the archive.
`verify-final.py` stays nonzero while any gate lacks evidence. G05 now checks the
controller's claim mount, G07 checks both controllers, G18 needs the reviewed doc
hashes, and delivery verification rejects zero replicas, stale generations,
partial rollout or wrong revision/image. Manual evidence remains necessary for
UIs, scaling, restart survival, drift and cleanup; no file-existence heuristic
or historical report is proof of runtime completion.

## Minimum external unblockers

1. Refresh the authenticated profile and resolve the OIDC SCP restriction for
   existing-cluster additions. Prior authenticated runtime reads are timestamped;
   later profile credential export failed. No broad IAM bypass is permitted.
2. Running Docker/build infrastructure and successful full application/CI image
   builds after vendor security upgrades, with complete scans/SBOM/digests.
3. Review the additive existing-addons plan and authorize only new prerequisites.
   The complete independent bootstrap/infra/platform workflow is mocked offline;
   no second EKS cluster or existing-state transfer is proposed.
4. Verify a quiesced consistent backup and functional recovery before separately
   approving existing Jenkins storage cutover. Local file restoration passed, but
   consistency, plugin/credential recovery and PVC survival remain unverified.
   Issue scoped GitHub tokens and reconcile exact app/signing secret references.
5. Actual approved DB ownership/grants/migrations and GitOps/application rollout;
   controller-side Jenkins syntax/core/plugin/build compatibility verification.
6. Approved scaling/persistence tests, full runtime evidence, repeated no-drift
   plans and distinct independent clean deployment/disposable cleanup.
7. Official rubric and final publication authorization, after every gate passes.
