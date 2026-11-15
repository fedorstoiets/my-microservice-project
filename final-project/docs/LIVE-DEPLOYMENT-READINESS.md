# GoalDevOps live deployment readiness

**Decision: BLOCKED. Migration HOLD remains active.**

Current verification: 2026-11-15 UTC (2026-11-14 America/New_York), from
03:09:59Z through 2026-11-15T03:12:15.737232+00:00. This update supersedes the earlier expired-auth
observations in this report. It is evidence preparation, not approval or a saved
execution plan. No speculative source changes, test-suite reruns, state transfers,
remote state persistence, Terraform apply/destroy, IAM writes, Kubernetes
mutations, SQL or Jenkins cutover occurred.

Evidence: [live-readiness.json](evidence/live-readiness.json). Raw state, plan,
policy and Kubernetes results remain private under
`/tmp/goaldevops-live-20261115T030959Z` (directory 0700, files 0600). They are not
submission artifacts. Arrange durable encrypted recovery copies before execution;
a temporary local directory is not an off-machine backup.

The controlling procedures remain [MIGRATION-RUNBOOK.md](MIGRATION-RUNBOOK.md),
[EXECUTION-PLAN.md](EXECUTION-PLAN.md) and
[MIGRATION-HOLD.md](MIGRATION-HOLD.md). P00–P09 ordering and separate approvals
are retained below.

## Identity, authentication and access

- **Verified:** account `227281812993`, authenticated `default` profile,
  assumed role `AccountFullAccessRole`. Environment access/secret/session/security
  token and credential-expiration overrides were removed from child processes.
  Parent shell/login configuration was not changed; credentials were not displayed.
- AWS CLI authenticated and performed current reads. Terraform initially could
  not consume the same login profile. One bounded follow-up exported fresh
  credentials from that profile through a pipe into Terraform's process memory;
  nothing was persisted or printed. That resolved authentication. The subsequent
  plan failed on the pre-consolidation dependencies described below. No further
  plan retries were made.
- Kube context/server was checked against the authenticated EKS endpoint before
  server reads. Cluster-wide pod/node/controller/storage reads, Helm list and
  `kubectl auth can-i get pods --all-namespaces` succeeded. These do not prove
  future write permissions or connectivity from the intended private runner.
- **Blocked:** `iam:ListOpenIDConnectProviders` is explicitly denied by SCP
  `arn:aws:organizations::682530816423:policy/o-id6ob2ophz/service_control_policy/p-uv1gtmxn`.
  No provider ARN was guessed; no duplicate provider was created/imported.
  Provider ownership/issuer/audience and IRSA authorization remain unverified.
  Role trust and existing inline ECR policy reads succeeded. Read success does
  not establish authorization for IAM, backend or deployment writes.

## Current state versions and ownership

Bucket `fedorstoiets-neoversity-tfstate-227281812993`, region `us-east-2`:
versioning **Enabled**, default encryption **AES256**. Discovery found four
`.tfstate` keys. Each object was read by immutable VersionId and its current
VersionId rechecked afterward. All four current hashes match the preserved
2026-11-14T20:12:31Z backups; lineages/serials are unchanged.

| Key prefix (`/terraform.tfstate`) | Current VersionId | Serial | Instances |
|---|---|---:|---:|
| final-project | `b6i9qOXP0xgd.23RZnukXTz0IY8h0.HW` | 3 | 6 |
| lesson-5 | `3GoEfpgRiDjCmBhU0rg_fRPZM.ZQvtBn` | 7 | 26 |
| lesson-7 | `pmMVXLk57kw73LLj2NvthAtwx_efwN.Q` | 2 | 10 |
| lesson-8-9 | `PWWaZMYzP5gaT5FtnMTUmZXisbg_rZy2` | 4 | 10 |

Lineages and SHA256 hashes are in the linked evidence. Current ownership:
**52 managed instances, zero duplicate type/ID candidates, zero deposed
instances** within these four discovered states. The historical 39-transfer map
still matches these identical snapshots; the proposed destination count remains
45 (six retained plus 39 transfers), subject to reviewed execution inventory.
This is not a global claim about other buckets, manual tooling or unknown owners.

Preserve all six original final-project records, especially `module.rds[0]` and
`helm_release.monitoring[0]`, the destination lineage, provider/tag bindings and
all data. Keep lesson-5 backend resources/unrelated ECR with their existing owner.
No transfers occurred. No S3 `.tflock` object was observed. Legacy
`terraform-locks` is ACTIVE with reported ItemCount 1; that count is not proof of
an active/stale lock (it may be a checksum record). No table item was modified or
force-unlocked. Client locking compatibility and coordinated write-freeze remain
required; current Argo auto-sync/pruning is still active.

## Drift and migration readiness

**Drift is not cleared.** One initial root refresh-only attempt failed before
refresh because of profile credential compatibility. The single authenticated
follow-up used `terraform plan -refresh-only -lock=false -input=false`, continuity
profile and a private output plan. No lock was acquired and no refreshed remote
state was saved. It produced an **incomplete, errored** plan:

1. RDS `private_subnet_ids` is empty: VPC resources still belong to lesson-5.
2. RDS ingress `for_each` keys are unknown: EKS resources still belong to lesson-7.

These are expected pre-consolidation dependency blockers for this execution
context, not grounds for speculative source edits, targeted applies or bypassing
HOLD. Prepare the approved private continuity workspace/rehearsal with frozen
chart/values and proper ownership context before complete plan review. Offline
state-editing rehearsal itself still requires explicit authorization under the
runbook. No refresh plans for the three legacy owners were executed in this batch;
their source/configuration continuity is not certified by unchanged state bytes.

The partial refresh observed a delta on
`module.rds[0].aws_security_group.database`: cached inline ingress `[]` now
includes TCP/5432 from `sg-0072c2bc38f9d15bc`. The same access is represented by
the separately owned `aws_vpc_security_group_ingress_rule.from_sg` in the existing
state. This may reflect parent-resource refresh of that standalone rule, not an
unauthorized firewall change. Review the exact rule/ID and provider behavior in
a complete plan; do not delete or duplicate the rule to erase this delta.
No no-drift, no-change continuity or saved apply-plan approval is asserted.

## Live health and prerequisites

| Component | Current verified evidence | Readiness limit |
|---|---|---|
| EKS/nodegroup | `neoversity-lesson-7` ACTIVE, version 1.37; nodegroup ACTIVE, no reported issues, two Ready amd64 t3.medium nodes; desired/min 2, max 4. Kubernetes server matches AWS endpoint. | Public and private endpoints enabled; public CIDR is `0.0.0.0/0`. Actual private-runner routing/TLS/RBAC must be proven before endpoint hardening. Customer KMS association absent; this is not proof of plaintext Kubernetes secrets. |
| Workloads | 26 Running/Ready pods plus one Succeeded migration pod; no pending/failed pods in this observation. Django controller 2/2 ready; controller/daemonset readiness collected. | Pod readiness is not UI, SQL correctness, least-privilege DB access or clean-bootstrap proof. Capacity and disruption budgets need review before adding builder/ESO/CSI workloads. |
| Jenkins | `jenkins-0` Running/Ready, controller 1/1; Helm jenkins 5.12.0 deployed. `/var/jenkins_home` mounts `jenkins-home` **emptyDir**. | No persistent claim or safe cutover attestation. Do not restart or upgrade controller before verified recovery. Live jobs/queue and credential functionality were not queried through authenticated Jenkins APIs. |
| Argo/GitOps | Argo controllers ready; Helm argo-cd 10.18.0 and Applications 0.1.0 deployed. `django-gitops` Synced/Healthy at `43a3a1b0b4d9129b3512d89bdf74d27089537862`. | **Automated sync, prune and self-heal are enabled.** Approved freeze is mandatory before source/state/cutover work. Do not push new GitOps content while active pruning can delete legacy resources. Freeze deployed chart bytes/values, not only chart version. |
| Monitoring | Helm kube-prometheus-stack 93.2.2 deployed; Grafana/Prometheus controllers ready; Prometheus readiness endpoint returned Ready; **19/19 active scrape targets up**. | UI/dashboard requirements and persistence tests remain separate; monitoring uses ephemeral volumes. Do not silently upgrade to desired-source 93.3.0 during ownership transfer. |
| Metrics | metrics-server 3.14.0 deployed/ready. | Actual controlled HPA/load tests not performed. |
| CSI/storage | Only managed add-on is ACTIVE Pod Identity agent v1.4.1-eksbuild.3. No EBS CSI controller/node workload, no PVC/PV, no gp3 SC observed. Only gp2 in-tree SC: WaitForFirstConsumer, Delete. | CSI, scoped IAM, compatible add-on version and retained Jenkins claim must be separately planned/approved. Add-on version compatibility not yet selected. |
| ESO | No external-secrets CRDs or ESO Helm release/controllers. | Missing installation/identity and reconciled SecretStore/ExternalSecret readiness; failed ExternalSecret query reflects absent CRDs, not proof of a credential fault. |
| Existing identity | Pod Identity association remains for `jenkins/kaniko-builder` and `neoversity-lesson-89-kaniko-pod-role`; trust is `pods.eks.amazonaws.com`. Inline ECR push/pull policy scopes repository `lesson-7-django` with global authorization-token action. No IRSA-annotated service accounts observed. | Preserve working identity. Runtime credential acquisition/ECR operation was not executed; no service-account annotation alone proves permissions. OIDC provider verification is SCP-blocked. |
| Security settings | Current EKS public endpoint is unrestricted; lesson-7-django ECR is MUTABLE; 3 project-VPC subnets auto-assign public IPs. | Source hardening has not been applied. Separate scoped security/IAM approval required; no live source-security closure is claimed. |

Current Helm list has five deployed releases: Jenkins, Argo CD, Applications,
monitoring and metrics-server. Deployed Helm values/manifests and authenticated
historical chart-content reconstruction were not collected here; version equality
alone cannot establish continuity. No Helm secret data was requested.

## RDS, secrets and recovery

- Intended database `neoversity-final-db`: **available**, PostgreSQL 18.6,
  private, encrypted, retention **one day**, deletion protection **false**,
  no pending modifications. Active automated backup/PITR window:
  `2026-11-14T03:03:01Z`–`2026-11-15T03:03:01Z`. Available automated snapshots:
  Nov 13 16:47:28Z and Nov 14 07:59:10Z. These are observed recovery points,
  not proof of a tested restore. A pre-change recovery point, retention/protection
  decision and restore rehearsal still need approval/evidence.
- Other account databases `fp-rds-db` and `hw6-rds-db` are not migration targets.
  Both have backup retention zero; hw6 is public. The manual `fp-rds-snapshot`
  belongs to **hw6-rds-db**, not neoversity-final-db. Do not use its name as proof
  of project recovery coverage or mutate those unrelated databases.
- App ConfigMap `django-app-config` points at the actual neoversity-final-db
  endpoint; current Django pods consume that ConfigMap and Secret
  `django-rds-secrets`. No Secret data was read. ConfigMap has no explicit
  POSTGRES_SSLMODE; TLS verify-full, restricted-role credentials and real DB/schema
  health remain unverified. No database connection or SQL was executed.
- The only secret returned by regional Secrets Manager listing is the active,
  rotating RDS-managed master secret, with an AWSCURRENT version. Exact ARN and
  version identifier are recorded in evidence. Its AWS-managed KMS key is Enabled
  and the key policy is readable. Workload GetSecretValue/Decrypt permission and
  credential validity were not exercised. No GetSecretValue request was made.
- Dedicated application-role, stable Django signing and distinct GitOps read/push
  secret references are not present in the observed regional list. Before
  provisioning, obtain exact intended account/region/ARNs, check existing manual
  Kubernetes Secret ownership, and avoid overwriting working credentials.
- Legacy `django-app-postgresql` is still Ready and uses **emptyDir** data; it
  consumes the same ConfigMap/Secret references. Its data and relationship to the
  working application must be inventoried/preserved before pruning or removal.
- Preserved Jenkins running-controller archive still matches recorded SHA256
  `ad3b3765bc6ad3b90124276eb0e0fbfbeb07583162697328c25b91fa4fba4529`. Prior safe-path/required-key validation remains evidence only of
  archive structure. **No consistent quiesced backup, successful restore, retained
  claim/PV or signed cutover readiness has been proven.** No current live backup
  or restore Job was executed; an authenticated controller must not be restarted
  based on that archive check alone.

## Consolidated outstanding conditions

The decision cannot change to READY FOR INDEPENDENT APPROVAL until:

1. Organization owners resolve the OIDC discovery SCP restriction or supply an
   authoritative provider/ownership verification path, and review effective
   IAM/OIDC/IRSA, key-policy and deployment permissions. Do not substitute an
   unverified identity mechanism.
2. Reviewers receive complete continuity/no-drift plans for all actual owners,
   exact physical-ID/provider map, reconciled SG refresh delta, frozen deployed
   chart/values and execution source manifest. Approve offline rehearsal before
   any scratch-state edits. Preserve destination RDS/monitoring and one owner per
   resource; confirm all versions again under approved freeze before writes.
3. A coordinated writer/reconciler freeze, compatible locking, durable encrypted
   state/recovery backups, named recovery operators and tested rollback are
   reviewed. Argo auto-sync/pruning is currently active and must be changed only
   under explicit authorization.
4. Exact CSI/IRSA/ESO/KMS/storage/secret plans, compatible versions, actual secret
   ARNs and retained Jenkins storage are reviewed. Prove private-runner access and
   workload capacity before hardening/cutover; existing identity remains intact.
5. Jenkins has a quiesced consistent backup, verified off-cluster recovery and
   restore/cutover evidence before any controller restart. Keep legacy database
   data and volumes intact; obtain a DB recovery/ownership/grants/TLS plan.
6. Actual application/CI image builds, scans, digests/SBOMs, unscored-advisory
   dispositions, live Jenkins syntax/identity/ECR and exact GitOps revision review
   are available. Source scans alone do not establish deployed-image safety.
7. Two operators review the exact phase-specific packet; state transfers,
   infrastructure/IAM/storage/secret writes, Jenkins downtime/cutover, publishing,
   SQL, sync/pruning and disruptive tests each receive explicit authorization.

G02 remains source-verified; live healthy observations support portions of the
runtime acceptance requirements but no gates are automatically promoted here.
G18 remains previously documented, without a new documentation attestation.
Full G01–G20 acceptance, independent clean deployment and final submission are
still open. No test-suite rerun was needed or performed.

## Exact dependency-ordered execution sequence and checkpoints

Each row is a future phase. Stop at any missing prerequisite, unexpected drift,
replacement/deletion, changed state/source version or failed health check.
The explicit approval scope must name the exact plan/artifact hashes, resources,
operators, maintenance window and rollback writes. Approval expires on change.

| Phase | Sequence and exit evidence | Rollback / stop checkpoint |
|---|---|---|
| P00 — Read-only preflight | Restore approved identity; verify real private runner and cluster; collect version-pinned states with `scripts/state-inventory.py --discover` plus authoritative nonstandard keys; collect all live prerequisites in the matrix; verify backups and execution source/frozen-chart manifest. Prepare complete private continuity and separate hardening plans, with no apply or state writes. Plan generation must not persist refreshed remote state; do not use refresh-only apply. | No mutation to undo. Any unread owner, duplicate/deposed instance, unknown version, unrecoverable backup or unavailable chart blocks P01. Keep raw states/plans/values private and encrypted off-machine. |
| P01 — Ownership only | After explicit freeze/offline-rehearsal/live-transfer approval, stop all approved writers/reconcilers; rehearse against private copies; use continuity profile, deployed values and frozen chart; review `check-plan.py` and exact ID/provider/count map. Remove approved source ownership before assigning destination ownership, with version checks and normal locking at each step. Re-inventory all affected owners and prove no-op plans and unchanged workloads before release. Preserve original RDS/monitoring records. | Transfers are non-atomic. Retain freeze on failure; establish precisely which writes completed. Separately reviewed rollback removes destination transferred ownership before restoring source ownership from current-state reconstruction plus backups. Never force-push old bytes, lower serials, or create duplicate owners. |
| P02 — Security hardening | With proven private access, review `review-security-plan.py` and new saved plan: retained rotating KMS key, in-place endpoint/encryption association, immutable ECR, disable public-subnet auto-IP only. Keep deployed Helm/chart freeze. Verify existing identities unchanged and private access/health after change. | KMS association is not reversible by reverting variables: retain key/grants for cluster lifetime. Endpoint recovery must use verified private access; any restricted public fallback requires separate authorization and actual approved CIDR. No open-CIDR emergency fallback. |
| P03 — IAM/CSI/storage | Resolve SCP constraints; reference verified existing owned OIDC provider or create only if absence proven. Approve exact IRSA/CSI/storage plan and compatible CSI version. Preserve Pod Identity during measured transition. Prepare standalone protected Jenkins claim without Helm/RDS changes; prove provisioning with approved restore consumer and viable AZ. Verify existing CNI enforcement before application policies. | Retain old identities/associations and current controller. Preserve new PV/claim and backups on failure; no automated cleanup/deletion. Pending WaitForFirstConsumer claim alone is not failure or readiness. |
| P04 — Secrets | Approve exact secret/KMS/ESO plan and secure provisioning channel. Provision/reuse actual app/signing/GitOps credentials and scoped access. Verify ESO readiness and target ownership without printing contents. Preserve prior signing key and valid secret versions. | Stop on ownership/access/role mismatch. Coordinated rollback to prior valid version requires review; do not blindly rotate/reset working credentials. Do not expose master credentials to web workload. |
| P05 — Jenkins recovery | First build/scan the exact recovery/CI image locally or on an approved isolated builder; authorize any image publication needed by restore. Approve downtime, quiesce and consistent backup; verify encrypted off-cluster copy. Render reviewed restore Job with actual image/backup/target claim, restore into fresh `restored/`, attest keys/jobs/plugins/credentials/UID and PVC/PV/AZ. Only then enable restore flag/delivery and deliberately clear Jenkins continuity values for reviewed cutover. Keep Argo/Application overrides/chart frozen. | Before first restart require a usable verified home. On failure keep jobs frozen and preserve all copies/PVs; recover with verified home and reviewed release configuration. Returning to an empty ephemeral home is not rollback. Authorize subsequent pod replacement/persistence proof separately. |
| P06 — CI/GitOps preparation | Obtain source/image publishing authorization; pin and scan app/CI images for measured worker architecture; validate actual Jenkins declarative syntax and identity/ECR access. Run build-only with `DEPLOY=false`, `PUBLISH_GITOPS=false`. Then authorize exact GitOps chart/digest publication with `PUBLISH_GITOPS=true`, `DEPLOY=false`, sync still disabled. Review rendered revision and freeze its HEAD. | No app rollout yet. Retain previous digests/revisions and working controller. Stop on image findings, unexpected files/values, concurrent GitOps writes or identity failure. A published artifact need not be deleted to roll back. |
| P07 — SQL/application | Review actual ownership/grant transition and DB recovery/compatibility first; obtain distinct SQL and sync approvals. Restore canonical Applications chart 0.2.0 and deliberately release only reviewed Argo/Application overrides. Keep pruning false and preserve legacy PostgreSQL/data. Sync order: wave -3 ESO Ready; optional approved wave -2 transactional role bootstrap; wave -1 migration hook; wave 0 application rollout. Verify exact revision/digest, positive ready replicas, TLS/DB/restricted role; disable one-time bootstrap afterwards under reviewed change. | Never bypass failed hooks. Stop on SQL preflight/hook failure. Application revision rollback requires schema compatibility review; image rollback does not undo SQL. Restore/PITR is disruptive, separately authorized, and requires a proven recovery point; preserve all data. No automatic legacy deletion. |
| P08 — Runtime acceptance | Collect exact G01–G20 evidence, UIs/metrics, workload identity, persistence, RDS/TLS/role and real pipeline/GitOps outcomes. Separately approve scaling/load and pod-replacement tests. Review refreshed complete plans for every actual owner; no unexpected drift. | Stop tests on health regression; retain evidence and backups. Reconciliation/rollback changes remain within explicitly approved scope. No gate passes with missing or skipped mandatory evidence. |
| P09 — Clean rehearsal/submission | Independently approve a distinct disposable environment: bootstrap → infra → platform → verified images/secrets → approved SQL/sync. Reconcile official rubric. Separately approve teardown and retained-resource/snapshot handling, then final publication only after all gates pass. | Never use existing RDS or lesson owners as clean-rehearsal/teardown targets. Retain backend, keys and recovery access until dependents are retired. No existing infrastructure cleanup is implied. |

P05's recovery-image prerequisite is built before Jenkins restart; P06 then
uses the recovered controller for CI verification. This avoids making recovery
depend on the Jenkins controller being recovered. No step assumes new deployment
roots can be applied to existing lesson-owned resources.

## One consolidated approval checklist

All boxes remain unchecked. This checklist consolidates review; it does not
combine the separate phase-specific authorizations into blanket permission.

- [ ] P00 evidence: valid principal/account/session, private-runner reachability,
  complete current state VersionIds/lineages/serials/IDs/providers and active-owner
  inventory; locking compatibility; actual IAM/OIDC/SCP/KMS/RBAC prerequisites.
- [ ] Exact execution source manifest, deployed chart artifact/values hashes,
  dependency versions and current validation receipt reviewed; source publication
  approval if required. Old `final-infra.tfplan` is not approved by this report.
- [ ] Fresh state/RDS/Jenkins backups, encrypted off-machine copies, named
  recovery operator, recovery objectives and demonstrated recovery accepted.
- [ ] P01 freeze, private state-edit rehearsal and exact live ownership writes
  separately approved by two operators, including version expiry rules and
  rollback reconstruction; RDS/monitoring/backend preservation confirmed.
- [ ] P02 exact hardening plan approved, including one-way KMS implications,
  private endpoint recovery and ECR/subnet effects; no replacements or unrelated
  RDS/Helm changes.
- [ ] P03 exact IAM/OIDC/CSI/CNI/storage writes and any adoption/node changes
  explicitly scoped; old working identity and retained volumes preserved.
- [ ] P04 secret/token issuance, secret writes/rotation, ESO ownership and KMS
  grants separately authorized with prior valid versions retained.
- [ ] P05 recovery-image publishing if needed, downtime/quiesce/consistent backup,
  restore Job, Jenkins release cutover and later persistence test explicitly
  approved; verified home/PV available before restart.
- [ ] P06 source/ECR/GitOps publishing approved for exact commits/digests;
  app/CI scans and unscored advisory dispositions accepted; build-only first.
- [ ] P07 database ownership/grants/schema SQL and application sync separately
  approved with tested recovery/compatibility; exact GitOps revision protected;
  pruning disabled and legacy data retained.
- [ ] P08 disruptive acceptance tests authorized; G01–G20 evidence reviewed.
- [ ] P09 distinct clean environment, cost, teardown/snapshots/retention and final
  publication individually authorized; official rubric reconciled.

**Next action:** resolve the organization-level OIDC discovery restriction and
prepare a reviewed private continuity execution workspace/rehearsal, with separate
authorization before any offline state edits. Use the demonstrated profile
credential bridge when Terraform cannot consume the login profile directly.
Complete continuity/no-drift plans, recovery proof and phase-specific approvals
before any live write. HOLD remains unchanged; this report requests no live execution.
