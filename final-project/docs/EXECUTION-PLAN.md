# GoalDevOps unified execution and acceptance plan

**Status: PREPARATION ONLY — MIGRATION HOLD ACTIVE — NO LIVE WRITES AUTHORIZED.**
This is the single review program for existing-state consolidation, security,
recovery, secrets and delivery. It is not a saved Terraform plan or an approval.
Real saved plans, fresh state versions and operator signoff are unavailable
while AWS authentication is blocked. `evidence/execution-readiness.json` records
missing inputs. The companion `scripts/prepare-execution-plan.py` can validate
private evidence without printing secret values or performing writes.

## Review packet and invariants

Record the actual AWS account, region, cluster ARN/issuer/API endpoint, kube
context and private-runner identity through approved authentication. Record all
active backend bucket/keys, VersionIds, lineages, serials, physical IDs and
provider bindings. Never fill missing identifiers with example/test fixtures.
The historical 52-instance inventory and 39-transfer map are reference material
only. Fresh discovery must include nonstandard active keys; distinguish archived
copies from active owners. Stop on duplicates, deposed resources or ambiguity.

Preserve `module.rds[0]` and `helm_release.monitoring[0]`, the primary
`final-project/terraform.tfstate` key, legacy tag aliases, data and all backups.
No plan may replace/delete an existing resource unless a later, separate scoped
approval explicitly permits it. Neither source tests nor this document permit
state writes, secret writes, image/Git publishing, SQL or controller changes.

Keep raw state, saved plans/JSON, live Helm values and backups in a new private
directory outside Git, mode 0700/0600 and encrypted off-machine recovery copies.
Store only hashes, inventory counts, action summaries and approval references
in the shareable packet. Plans can contain passwords even when terminal output
is redacted. Do not print secret values, registry tokens or Jenkins recovery keys.

Capture the exact reviewed source manifest, current local-validation fingerprint,
all private artifact hashes and proposed variable files. Migration execution
needs a private source workspace containing the verified deployed Applications
chart in its original relative path until P07. Helm values overrides alone do
not freeze chart bytes/version. Reconstruct that chart from an authenticated
Helm/source artifact and compare its manifest; a matching version number or
unverified Git HEAD is insufficient. Record this deliberate frozen overlay in
the execution source manifest. Validate that workspace's Terraform and its real
no-change plan separately; desired-source chart tests describe the new chart,
not this intentionally frozen historical chart. Never overwrite the public
working tree or backend with scratch state/source.

## Parameters and approval boundaries

| Parameter/artifact | Required proof |
|---|---|
| `security_profile=continuity` | P01 only, generated private deployed Helm inputs and frozen chart |
| `security_profile=hardened` | P02+, verified private runner and independent security plan review |
| `private_runner_verified=true` | Read-only DNS/API/TLS/authorization from the actual private execution runner; not a permission flag |
| `existing_oidc_provider_arn` | If present, actual provider ownership and issuer/audience read verification; never duplicate-create/import an owned provider |
| `enable_irsa`, `enable_ebs_csi`, CSI version | Approved IAM/CSI plan and AWS compatibility/permissions evidence |
| `prepare_jenkins_storage=true` | Separate storage preparation only; keep deployed Jenkins Helm values frozen |
| `jenkins_restore_verified=true` | Consistent backup, exact restored claim/PV, keys/jobs/plugins proof and signed recovery rehearsal |
| `delivery_inputs` | Actual scanned CI/builder digests, exact app/signing/GitOps secret ARNs, KMS key ARNs and reviewed GitOps base commit |
| `enable_delivery_v2=true` | P05/P06 cutover approval; clear only Jenkins continuity values; keep Argo/Application overrides frozen through recovery |
| Jenkins `DEPLOY=false` | Build/scan/publish artifact only; no GitOps write or rollout |
| `enable_application_sync=true`, `DEPLOY=true` | Explicit P07 application/GitOps deployment approval |
| `enable_database_bootstrap=true` | Separate SQL approval; one-time bootstrap after ownership/role/logging preflight; false again after completion |

The root now includes additive ESO secret chart, scoped verifier RBAC, builder
configuration, protected Jenkins claim and existing-controller cutover wiring.
They are disabled by default. Enabling delivery without CSI/IRSA/ESO, complete
metadata, restored storage, or releasing Jenkins continuity values fails validation. Application sync additionally
requires deliberately releasing the separate Argo/Application overrides.
The separate new-environment platform has the same sync/SQL opt-in boundaries.
No phase is automatically authorized by selecting a variable value.

## P00 — authenticated read-only preflight

Restore approved AWS authentication and verify STS privately. Run state inventory
with discovery and all known/nonstandard keys using `scripts/state-inventory.py`.
Confirm object versioning, actual encryption/locking permissions and access to
all four owners. An unread state or denied bucket discovery blocks a claim of
exclusive ownership until an authoritative owner inventory is provided.

Verify kube context points at the measured EKS endpoint. From the intended
private runner, check DNS, route/security-group reachability, API TLS and read
RBAC before disabling public access. AWS EKS already enables default envelope
encryption on 1.28+; the recorded 1.37 snapshot is not proof of plaintext secrets.
The proposed customer key is explicit control/defense in depth, not evidence
that AWS-owned encryption was absent. Review its one-way association and KMS
permissions/recovery implications before any authorization.

Read ECR mutability/scan settings, subnet attributes and actual node/pod network
placement. Read OIDC issuer/provider/client IDs, role trust/policies, CSI/CNI
versions, gp3/PVC/PV/AZ data, RDS engine/orderable class/backup/snapshot/encryption,
Secrets Manager metadata, ESO readiness, Jenkins chart/home/queue/jobs, Argo
source/revision/sync and monitoring targets. Read secret metadata and conditions,
not Secret data. Verify memory/CPU capacity for the CI builder plus existing
Jenkins/monitoring workloads; any necessary node rollout needs a separate plan.

Record least-privilege allowed actions and actual SCP restrictions. A previous
SCP denial is not permission to substitute an unverified identity mechanism.
Current authentication is unavailable, so none of these live observations has
been asserted as current by this source review.

## P01 — ownership-only consolidation

Submit a packet covering a coordinated write-freeze on all Terraform owners,
CI/operators and reconcilers, normal compatible locking, verified immutable state
backups, resource-by-resource IDs/provider/tag continuity, exact source/frozen
chart/values, complete rollback and second-operator signoff. Freezing Jenkins or
Argo is itself a mutation requiring explicit authorization before it happens.

Prepare private scratch copies and continuity inputs with
`scripts/continuity-values.py`. The tool explicitly selects the continuity
profile. State-editing rehearsal and live state writes both require approval;
no such commands are run by the helpers. Use the address map in
MIGRATION-RUNBOOK.md only after comparison with the fresh inventory.

Check a complete private Terraform JSON plan with `scripts/check-plan.py` and
`--expected-managed-count` derived from the new ownership map. The guard rejects
empty/malformed/incomplete plans, drift, imports, missing IDs, count changes and
all managed writes. The packet tool additionally compares every planned physical
ID/address with the reviewed inventory. The historical target is 45 instances
(6 retained + 39 transferred), but use the actual refreshed count, not that
historical assumption. Review provider aliases/default tags independently.

After separate explicit live-state approval, remove approved source ownership
before assigning destination ownership under the verified freeze. Transfers are
not atomic; no apply/reconciliation may run during the unmanaged interval. Never
create two active owners, force-push old state, lower serials, or overwrite S3
with scratch files. Keep backend/unrelated lesson-5 ECR with their current owner.
Recheck versions before every write and ownership after each step.

On failure retain the freeze and reconcile which writes completed. Rollback
removes transferred destination ownership before restoring source ownership
using reviewed current-state reconstruction plus verified backups. It never
replaces the original destination RDS/monitoring records. Re-review every rollback
write; do not force-restore old S3 bytes. Release the freeze only after exclusive
ownership, no unintended managed changes, unchanged workloads and second review.

## P02 — separate in-place security plan

Continue deployed Helm overrides and frozen chart. Propose only:

| Address | Allowed intended operation |
|---|---|
| `aws_kms_key.eks_security[0]` | Create retained rotating key, at least 30-day recovery window |
| `module.eks.aws_eks_cluster.main` | In-place private-only endpoint and explicit encryption association |
| `module.ecr.aws_ecr_repository.main` | In-place immutable tags |
| `module.vpc.aws_subnet.public[0..2]` | In-place disable auto public IP allocation |

Set hardened profile only after private runner evidence. Generate a new complete
saved plan and private JSON; run `scripts/review-security-plan.py`. The allowlist
rejects replacement/deletion, unrelated attributes and any RDS/Helm/other managed
changes. The packet comparison must preserve every existing physical identity.
Review Terraform proposed unknowns and KMS policy/grants separately; guards do
not replace review. Check existing ECR tag behavior and full-SHA/digest build
compatibility before approval. Disabling auto-IP affects future ENIs; it does
not revoke addresses already allocated to existing workloads.

Customer-key association cannot be undone by reverting a variable. After it is
executed, never return to the pre-hardening continuity profile or delete the key.
Keep encryption/key for the entire cluster/recovery lifetime. Endpoint recovery
uses the proven private runner; any emergency restricted public-access change
requires a separately approved real CIDR and a reconciled Terraform plan, never
an unreviewed `0.0.0.0/0` rollback. These source fixes do not claim live remediation.

## P03 — IAM, CSI and storage preparation

After SCP resolution and a reviewed plan, either reference the actual existing
OIDC provider (the source verifies issuer/audience) or create a new owned provider
only if inventory proves none exists. Use exact service-account subjects and STS
audience. Preserve existing Pod Identity until new IRSA credentials and ECR
operations are verified; do not delete old roles/associations in this batch.

Review EBS CSI role/policy, AWS-supported add-on version and gp3 compatibility.
Enable only the reviewed CSI/storage inputs; keep Jenkins deployed values and
Application chart frozen. Create the protected standalone `jenkins-home` claim
with WaitForFirstConsumer and Retain policy. Inspect existing StorageClass/claim
ownership first; an existing unmanaged object requires separately reviewed
adoption or a deliberately different name, not an unconditional duplicate create.
Root storage preparation must not update any Helm release or RDS resource.

Wait for CSI and perform the approved restore consumer in a viable AZ; a Pending
claim before its first consumer is expected. Verify real volume provisioning and
IAM permissions; add-on presence alone is insufficient. Existing CNI enforcement
must be inventoried and explicitly configured/adopted before enabling application
NetworkPolicy; the fresh infra path configures it, the existing path does not
pretend its enforcement has already been installed.

## P04 — secret provisioning

Review actual encryption key ownership/grants and exact required secret ARNs.
Provision or reuse app credentials, stable signing key and distinct fine-grained
GitOps `push_token` / `read_token` through an approved secret-management channel.
Existing-environment secret values are externally provisioned; new infra uses
ephemeral/write-only generated app/signing values. Record their actual metadata
in private `delivery_inputs`; never pass secret values in Terraform/Helm/CLI
arguments or logs. Scope ESO Get/Describe and KMS decrypt to those exact secrets
and keys through Secrets Manager. The web app must not reference the master ARN.

The role/grant transition and Secret contents must agree on the actual app role.
Do not reset a signing key or rotate an existing working credential casually.
Plan a coordinated rotation and rollback retaining the previously valid secret
version. ESO target ownership must be checked before replacing a manual Secret;
blind adoption can overwrite working credentials. Token issuance and every
Secrets Manager write require separate explicit authorization.

## P05 — Jenkins recovery and cutover

Before any change that restarts the ephemeral controller (including plugins,
environment or JCasC), obtain downtime/recovery approval. Quiesce new builds,
back up an application-consistent home including master key and credential
cipher material, hash and encrypt an off-cluster copy, and verify restoration.
The old running-controller archive was path/key validated but is not proof of
application consistency. Preserve it and all existing data.

Use the safe archive verifier/restorer and suspended Job renderer with the actual
scanned CI image, backup PVC and target claim. Do not submit the unresolved raw
restore template. Restore to the fresh `restored/` subdirectory as Jenkins UID
1000, validate ownership/plugins/jobs/credentials privately, and record the exact
PVC/PV/AZ and checksum. Only then set restore attestation and enable delivery.
Clear Jenkins continuity values deliberately for the reviewed cutover plan;
keep Argo server/Application values and the frozen historical chart unchanged until P07.
review the complete Jenkins/plugin/Argo release changes rather than merely the
persistence boolean. Do not combine a node/DB replacement with this cutover.

On failure keep jobs frozen, preserve retained PV/backups, and use the reviewed
recovery procedure with a verified home. An empty ephemeral rollback is not a
recovery. After successful cutover, separately authorize pod replacement and
prove the same PV and preserved home marker/credential functionality.

## P06 — CI artifacts and GitOps preparation

Obtain a reviewed source commit/publishing authorization; the current dirty
working tree is not remotely available to Jenkins. Build `ci/Dockerfile` for
actual workers (default t3 nodes are amd64), scan it and the application image,
produce SBOMs and publish only after ECR write authorization. Resolve actual
image digests. New recipes use a verified Alpine Python base and vendor security
floors; a recipe is not proof those upgraded images built or scanned successfully.

The old archived Kaniko image scan reports 11 CRITICAL/228 HIGH occurrences.
Do not use it for new rollout. The verified maintained debug image is recorded
in image-pins.json and rejects the archived registry path in new rollout inputs.
Its 0 HIGH/CRITICAL scan still has two distinct unscored advisories; the reviewer
must resolve applicability/fixes or record a time-bounded disposition. The
scanner stage's vulnerable Git packages are not copied into the runtime CI image;
only its Trivy binary is copied, whose own unscored advisory remains visible.

Start Jenkins with `DEPLOY=false`: exact source checkout, tests, immutable ECR
lookup/build and image scan, with archived image reference; no GitOps push or
waiting for deliberately disabled Argo sync. Validate Jenkins declarative syntax
on the real controller before running; local checks cover pod YAML/CLI/core/plugin
metadata, not a live Jenkins model compilation. Confirm real registry/ECR helper
and IRSA identity without printing tokens. Legacy/new identity coexistence must
be measured, not inferred from annotation presence.

Review the exact initial GitOps HEAD and chart diff. Extra files, symlinks and
modified canonical templates cause the tool to stop. Preserve environment values
and validate actual rendered destination values, secret references and image
before agreeing to replacement. A scoped GitOps write needs separate authorization.

## P07 — separately authorized SQL and application deployment

Keep Argo sync disabled while inspecting existing schema owners, role memberships,
app/master separation, migrations, TLS and server audit/logging policy. Existing
Django objects owned by the master require an actual object-by-object approved
ownership/grant transition; the fresh bootstrap intentionally refuses foreign
objects or privileged/membership-bearing app roles. Prepare/review that SQL from
live metadata; do not invent object names or execute the fresh bootstrap blindly.
Ensure session-level credential logging controls are permitted before password
DDL. The bootstrap is one transaction and fails before writes on unsafe preflight;
audit extensions/SQL permission constraints can still block it and need review.

After separate SQL/deployment authorization, supply approved image/GitOps revision,
enable application sync and enable the one-time bootstrap only where reviewed.
At wave -3 ESO must reconcile app/admin/signing secrets; Argo waits for Ready.
At -2 the role initializer runs if explicitly enabled; at -1 a migration Sync
hook completes; wave 0 rolls the application with maxUnavailable 0. Readiness
checks schema/DB and restricted role; liveness does not depend on RDS. Verify
projected credential rotation and TLS hostname/CA. Disable bootstrap afterwards
and remove long-lived admin Secret exposure under a reviewed cleanup change.

First publish the reviewed GitOps chart/digest with `PUBLISH_GITOPS=true` and
`DEPLOY=false` while cluster sync remains disabled. Review the complete rendered
revision and protect that GitOps HEAD from concurrent writes. Only then restore
canonical Applications chart 0.2.0, deliberately clear Argo/Application continuity
overrides and review the sync/SQL plan. The module refuses to release frozen
values against the legacy chart. Automatic pruning remains false: inventory and
retain/backup legacy PostgreSQL workloads/data and all other extraneous resources
before proposing any individually approved deletion. Do not enable pruning merely
to make Argo green. Unresolved legacy ownership/deletion remains an acceptance
blocker. The approved `DEPLOY=true` CI run publishes GitOps and verifies the exact
revision, digest, positive ready replica count and complete rollout/DB health.
Read-only verifier RBAC has no write/secret permissions. Roll back application
revisions only with database compatibility reviewed; image rollback cannot undo
SQL. Preserve all data and snapshots on failure. Never bypass failed hooks.

## P08 — runtime evidence and drift

Use the exact G01–G20 matrix in ACCEPTANCE-EVIDENCE.md. Collect current healthy
workloads, bound volumes, three UIs, targets/live metrics, correct app RDS/TLS/role,
real pipeline/ECR/GitOps evidence and least-privilege identity results. Authorize
controlled scaling/load and persistence replacement tests separately. Require
matching image/revision, no missing/skipped mandatory checks and raw evidence
hashes. Re-run complete refreshed Terraform plans for each actual owner; any
unapproved change/replacement blocks G16 and acceptance.

## P09 — independent clean rehearsal, teardown and submission

Existing-state consolidation does not prove clean bootstrap. Independently deploy
a distinct approved environment through bootstrap → infra → platform → reviewed
CI artifacts/secrets → authorized SQL/application sync. Use real compatible
versions and private access; never run these new roots against existing owners.
No existing database is a teardown test target. On a disposable environment,
separately approve backups, stopping reconcilers/finalizers, platform teardown,
RDS protection/final snapshot handling, retained volumes and infrastructure
cleanup. Retain backend/KMS/state/recovery access until every dependent state and
artifact is safely retired. G17 requires actual evidence, not this procedure.

Resolve external rubric requirements, security/image dispositions and all gates.
Only then authorize commit/push of a clean `final-project` branch and create a
matching final archive. The packager refuses a dirty development branch or open
G01–G20; current output remains a draft. No publication or teardown is authorized
by the fact that this plan exists.
