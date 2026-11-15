# GoalDevOps coordinated deployment authorization package

**REVIEW ONLY — MIGRATION HOLD ACTIVE — EXECUTION NOT AUTHORIZED.**

This package defines the approvals and exact artifact boundaries for the existing
environment. It does not authorize a state edit, apply, secret write, controller
freeze, SQL operation, Jenkins restart or publication. Existing source and all
working deployments remain intact. No administrator requests have been sent.

Use this package with [EXECUTION-PLAN.md](EXECUTION-PLAN.md),
[MIGRATION-RUNBOOK.md](MIGRATION-RUNBOOK.md) and the current
[LIVE-DEPLOYMENT-READINESS.md](LIVE-DEPLOYMENT-READINESS.md). It adds concrete
plans and proposed operations; it does not repeat the health audit. Machine
evidence and plan hashes: [authorization/package.json](authorization/package.json).
Approval signatures are deliberately absent.

## 1. Artifact inventory and plan decision

Private artifacts are under `/tmp/goaldevops-authorization-20261115T032122Z`,
mode 0700, files 0600. Raw state, deployed Helm inputs, saved binary plans and
full plan JSON must remain outside Git. `/tmp` is not durable recovery storage:
an encrypted off-machine copy and a named recovery operator are approval inputs.
The public package contains identifiers, hashes and sanitized action summaries,
never secret values. Use `authorization/checksums.sha256` to verify review files.

| Review item | Artifact / scope | Result |
|---|---|---|
| Four fresh owners | Private `states/summary.json`, `ownership.json`, version-pinned backups | 52 instances; no duplicate type/ID candidates or deposed records. All four VersionIds remained unchanged after planning. |
| lesson-5 | `lesson-5-{drift,continuity}.tfplan` | Both complete; continuity: 26 resources, zero managed changes. Three refresh-delta records. |
| lesson-7 | `lesson-7-{drift,continuity}.tfplan` | Both complete; continuity: 10 resources, zero managed changes. Five refresh-delta records. |
| lesson-8-9 | `lesson-8-9-{drift,continuity}.tfplan` | Both complete; continuity: 10 resources, zero managed changes. Five refresh-delta records. |
| final-project original owner | `final-project-deployed-inputs-{drift,continuity}.tfplan` | Both complete; continuity: six resources, zero managed changes. Two refresh-delta records. |
| Resource identities | Each plan compared with current owner inventory | All four continuity inventories match every expected address/physical ID. Refresh-only plan identities are in `prior_state.values`, not its empty managed `planned_values` section. |
| Frozen Applications chart | Private `frozen_application_render.stdout` versus `deployed_application_manifest.stdout`; file/hash manifest in package JSON | Canonical YAML is identical. Freeze original relative path `modules/argo_cd/charts/applications`, version 0.1.0, and exact deployed values until P07. |
| Migration map | [migration-map.json](authorization/migration-map.json) | 39 proposed transfers, exact current IDs/providers; 13 retained instances. No transfer executed. |
| Argo freeze | [freeze-argo.jsonpatch](authorization/freeze-argo.jsonpatch) | Prepared guarded patch only; never submitted. |
| IAM/backend requests | JSON files linked in section 4 | Proposed request documents only; no grants/attachments/requests sent. |
| CSI/ESO/storage | [phase-inputs.review.json](authorization/phase-inputs.review.json), [storage-render.review.yaml](authorization/storage-render.review.yaml) | Source-derived intent and exact compatible versions. Not executable tfvars or an alternate Kubernetes deployment path. |

Every plan was created with `-lock=false -input=false`; drift plans additionally
used `-refresh-only`. There was no Terraform apply, refresh-only apply, lock
acquisition, import, remote state persistence or state command. Read-only plans
cannot protect against concurrent writers; current object versions and freeze
must be reverified before any future execution.

### Plan provenance and rejected artifacts

The three lesson workspaces copy their existing source and actual local inputs.
Helm review overlays pin the exact state-recorded values and deployed versions.
The final-project review workspace reconstructs its **original six-resource
owner configuration** from local Git commit
`35fc225495517f33b0444f1e5c0e8434721163f0`, with state-derived deployment inputs
and recorded provider lock selections. It is not the canonical held consolidated
root. Private source manifests record every file/overlay hash.

The original owner's defaults disable RDS and monitoring. A plan prepared before
reconstructing its historical enable flags proposed deletion of all six retained
resources. **That plan is rejected and must never be applied**:
`final-project-reconstructed-continuity.tfplan`; its hash is in package JSON.
The final allowlisted review plan uses `deploy_database=true`,
`deploy_monitoring=true`, and actual database/version/class/chart inputs. No
deletion was executed. Select artifacts by final exact filename and hash, never
by wildcard or newest timestamp. An earlier empty archive-path preparation and
its failed diagnostics remain private historical evidence, not final plans.

### What these plans do not authorize

These are complete **current-owner** drift and continuity plans, not a fabricated
post-transfer consolidated plan. Preparing the latter needs an explicitly
approved offline state-transfer rehearsal. The user's current prohibition on
state transfers was respected, including scratch transfers. Source-retirement
plans also require that rehearsal's actual resulting owner states.

All four continuity plans have zero managed changes, but the unmodified
`scripts/check-plan.py` still rejects each with:
`Refresh detected drift; investigate before proceeding`.
No findings were suppressed and no guard was weakened. Complete original-owner
plans resolve the earlier empty-subnet/unknown-SG planning problem without
changing canonical source or live ownership. They do not clear migration HOLD.

## 2. Drift dispositions and the RDS security-group delta

The 15 exact address/attribute records are in `package.json`'s `drift_ledger`.
Each remains pending independent acceptance. Current continuity plans propose
no resource writes in response to any of these observations.

| Owner | Observed refresh difference | Proposed disposition / required review |
|---|---|---|
| lesson-5 | ECR null-to-empty tags; previously blank NAT EIP computed association/ENI/private IP/DNS; parent private route-table view gains default NAT route | Verify unchanged EIP/NAT IDs and separately managed route. Treat normalization/parent views as state observations, not new network changes. |
| lesson-7 | Null-to-empty ECR tags, EKS log list/security-group list, node labels; IAM role parent views gain separately attached policies | Verify existing policy attachment resources and actual cluster configuration; do not detach policies or alter EKS merely to erase refresh differences. |
| lesson-8-9 | Empty namespace/SA labels and annotations; empty add-on/role tags; role parent view gains separately managed inline ECR policy | Verify same policy/SA/namespace identities; no policy or workload change is proposed. |
| final-project | RDS PITR timestamp advances, empty domain/log-export lists; parent database SG gains ingress view | Timestamp is dynamic and may advance again. Preserve the existing separately managed ingress rule described below. |

**Exact RDS rule evidence:** database group `sg-065634bff1ea7823e` contains
`sgr-0bdf69b8c5c0b27b2`, ingress TCP/5432 from EKS group
`sg-0072c2bc38f9d15bc`, account `227281812993`. This is the same rule owned at
`module.rds[0].aws_vpc_security_group_ingress_rule.from_sg["sg-0072c2bc38f9d15bc"]`.
The parent SG cached ingress was `[]`; refresh now reports this child rule.
There is no second firewall rule to create and no removal to approve. No
configuration repair to that SG is proposed.

Approval options are deliberately separated:

1. Accept the documented observations for review, without changing state. This
   does **not** make the strict migration guard pass.
2. Separately authorize the exact complete refresh-only plans to persist reviewed
   state observations/outputs, after inspecting all deltas and current versions.
   This is still `terraform apply` and is **not authorized now**. It must not
   contain any resource mutation. Save fresh backups first; review lineage/serial
   and output effects afterward.
3. Rebuild rehearsal/continuity plans against those new versions. Do not reuse
   approvals or binary plans tied to superseded states. Dynamic PITR fields may
   recur; retain fail-closed behavior and refer any remaining delta to independent
   reviewers. A human disposition is not a silent bypass of `check-plan.py`.

## 3. Freeze, migration and recovery procedure

### F — coordinated writer/reconciler freeze (proposed, not performed)

The captured patch tests both Argo Application `metadata.resourceVersion` and
the complete observed automated policy before replacing it with
`enabled=false`, `prune=false`, `selfHeal=false`. It preserves destinations,
source revision, finalizers and all workloads. Record/check absence of a running
sync operation; wait for any existing operation to finish before the maintenance
window. Never terminate an operation or remove a finalizer implicitly.

After explicit F approval only, an operator would submit the exact reviewed
JSON patch to `argocd/django-gitops`. A stale resourceVersion invalidates it:
read current state and regenerate/review the patch rather than dropping tests.
Verify server-side policy, unchanged revision/digest/replicas, no running sync
and unchanged workload health. Do not run this command during preparation:

```text
kubectl --context arn:aws:eks:us-east-2:227281812993:cluster/neoversity-lesson-7 \
  -n argocd patch application django-gitops --type=json \
  --patch-file=docs/authorization/freeze-argo.jsonpatch
```

This is one proposed Kubernetes write, not a freeze of every writer. The same
maintenance approval must name operators responsible for:

- Jenkins authenticated quiet-down/new-build inhibition, draining existing builds
  and queue, and capturing job/queue state. Authenticated Jenkins API access and
  exact job inventory are still external inputs. Do not restart Jenkins to freeze
  it; its home is ephemeral. Quiet-down does not prevent external Git pushes.
- Freezing source/GitOps branch writes, webhooks/schedulers and all four Terraform
  owners' automation/operator sessions; identifying any external state owners or
  controllers. Record actor/window and acknowledgement from every writer.
- Keeping reconciler/manual-sync inhibition active throughout ownership gaps,
  without deleting releases, Applications, finalizers or database objects.
- A named operator checking state versions/locks, AWS session lifetime and
  health continuously; normal per-state locking for any later approved writes.
  Observed clients use Terraform 1.14.3 and native S3 lockfiles; lesson-5 also
  configures DynamoDB. Exclude incompatible/unknown clients through the freeze.

Freeze recovery is **not** automatic reenablement of pruning. The captured
[original policy](authorization/argo-original-sync-policy.json) is review material.
Before release, verify safe GitOps content, legacy data retention, exact approved
revision and all owners. Reenable only the specifically approved controls;
keep pruning false until deletions are separately reviewed. Jenkins resumption
is separate from Argo sync release.

### M0 — offline rehearsal (requires new explicit authorization)

1. Create fresh encrypted private backups and an immutable source/artifact
   manifest; recheck every owner VersionId, lineage, serial and physical ID.
2. Use **isolated local-backend** working directories and private state copies.
   Never run scratch state operations from a directory initialized to production
   S3. Do not write scratch bytes to the production backend or modify public source.
3. Apply the 39-row address map only to those local copies. Validate default-to-
   `aws.legacy5` / `aws.legacy7` module provider resolution and historical tags in
   the actual consolidated configuration; do not assume an FQN replacement tool
   can rewrite aliases. Preserve resource IDs, dependency records, destination
   lineage and the six original final-project resources. Do not import resources
   already owned by another state.
4. Freeze the proved Applications chart/values at their original relative path
   in the private execution source, with `security_profile=continuity`. Keep all
   deployment/SQL/pruning/storage flags disabled. No security or Helm upgrade may
   be included in the ownership rehearsal.
5. Prepare destination **and retained-source** configurations for the resulting
   ownership. Remove transferred resource declarations only in private retirement
   candidates; preserve compatible outputs for downstream consumers using actual
   destination outputs. Inventory those consumers before retiring lesson outputs.
   Reconcile complete plans for the final 45/7/0/0 owner counts and all IDs.
6. Require complete, nondeferred no-managed-write plans and unchanged strict
   guard results after independently approved drift handling. Include output,
   provider/tag and frozen-manifest review. Any create/update/delete/replacement,
   import, missing ID, duplicate owner or unexplained delta blocks live M1.
7. Rehearse failure after each source/destination write boundary, reconstruct
   rollback from current copies plus backups, and record operator signoff.

No local state command was executed to manufacture this evidence. M0 is the
minimum authorization needed to finish the consolidated-target and retirement
plans; the packet is explicit about that remaining deliverable.

### M1 — live ownership transfer (later separately approved packet)

Use exact reviewed source/target state push artifacts from M0, fresh source
versions, normal locking and the verified F freeze. Never use force pushes,
serial decreases, imports of owned resources or S3 overwrite as a shortcut.
Cross-state transfers are non-atomic. For each batch **remove source ownership
before assigning destination ownership**; prevent all applies/reconcilers during
that unmanaged interval. Verify the completed source write before destination
write and record both new immutable versions.

| Batch | Source removal | Destination count after successful assignment | Source count after batch |
|---|---|---:|---:|
| M1a | 19 lesson-5 VPC instances | 25 | lesson-5: 7 |
| M1b | 10 lesson-7 EKS/ECR instances | 35 | lesson-7: 0 |
| M1c | 10 lesson-8-9 namespace/Helm/identity instances | 45 | lesson-8-9: 0 |

This table specifies review batches, not permission to run them. For every
boundary, pull affected states read-only, compare versions/serials/lineages,
recount IDs, verify no duplicate ownership and prove original RDS/monitoring
records remain. Stop on conflicts, expired authentication, unexpected writes or
health regression. Retained lesson-5 backend/ECR instances never move. Do not
apply stale pre-transfer configurations to emptied states: they would recreate
resources. Keep their writers frozen until retirement configs are reviewed.

### Rollback and release

- On failure keep F active and stop all applies. Establish exactly which writes
  completed using actual current object versions, not intended batch position.
- If only source removal completed, restore that source's ownership through a
  reviewed reconstruction with current serial/lineage. If destination assignment
  completed, first remove the transferred destination ownership, verify it is
  absent, then restore source ownership. Do not restore both sides together.
- Preserve original destination RDS/monitoring records throughout. Never push an
  old destination backup wholesale or force-restore an old S3 version. Rollback
  writes require explicit authorization covering those exact new artifacts.
- Verify exclusive ownership, exact retained IDs/provider/tag behavior,
  complete no-managed-write plans, unchanged RDS/Helm/workloads and second-operator
  signoff before releasing Terraform writers. Keep application sync/pruning and
  Jenkins jobs in their approved freeze state until their own release checkpoints.

## 4. Administrator requests — exact scopes, not assumed permissions

**Recipient:** organization/SCP administrator and account IAM/platform owner.
The durable observed IAM principal is
`arn:aws:iam::227281812993:role/managed/AccountFullAccessRole` (from actual role
inventory, not a guessed STS-to-IAM path). Current assumed-role session is in
package JSON. Target account/region: `227281812993` / `us-east-2`.

### A1 — unblock provider ownership verification

Evidence identifies explicit deny in:
`arn:aws:organizations::682530816423:policy/o-id6ob2ophz/service_control_policy/p-uv1gtmxn`.
Request administrator review of its actual statements and inherited policies,
then a narrowly scoped exception for the reviewed principal/action/resources;
alternatively provide authoritative provider ownership and verification evidence
through an approved read-capable operator. Do not detach an organization-wide
guardrail or attach an Allow expecting it to override an explicit Deny.

[iam-oidc-read-request.json](authorization/iam-oidc-read-request.json) requests:

- `iam:ListOpenIDConnectProviders` on `*` for discovery.
- `iam:GetOpenIDConnectProvider`, `iam:ListOpenIDConnectProviderTags` scoped to
  the canonical expected issuer ARN derived from the **observed** EKS issuer:
  `arn:aws:iam::227281812993:oidc-provider/oidc.eks.us-east-2.amazonaws.com/id/DDF930235860D5B13B8F3342191ED95F`.

That scope is **not proof the provider exists**. Administrator response must
include actual ARN/owner, URL, `sts.amazonaws.com` audience, all active state
owners and effective permission path. Never create/import a second owner.
If SCP review needs Organizations access, the organization administrator uses
`organizations:DescribePolicy`, `ListPoliciesForTarget` and `ListParents` in
their own authorized context; application operators do not need policy-edit
rights. An SCP exception and identity permission are both needed where applicable.

### A2 — scoped IRSA/CSI/ESO provisioning permissions

[iam-irsa-change-request.json](authorization/iam-irsa-change-request.json) is a
proposed identity-policy fragment, not an SCP replacement or an attachment.
It scopes creation/read/trust/inline-policy/tag actions to these proposed roles:

- `neoversity-lesson-7-ebs-csi-irsa`
- `neoversity-lesson-7-kaniko-irsa`
- `neoversity-lesson-7-external-secrets-irsa`

Require `sts:AssumeRoleWithWebIdentity` trusts with exact issuer, STS audience and
subjects respectively:
`system:serviceaccount:kube-system:ebs-csi-controller-sa`,
`system:serviceaccount:jenkins:kaniko-builder`,
`system:serviceaccount:external-secrets:external-secrets`.
The current Pod Identity role/association remains intact. Check every proposed
role name for existing ownership before creation; a collision requires review,
not adoption or replacement.

The fragment grants `iam:AttachRolePolicy` only for source-referenced
`arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy` on the CSI role,
policy/version reads, and `iam:PassRole` for that CSI role to
`eks.amazonaws.com`. OIDC creation is conditional on authoritative absence and
the separate reviewed P03 plan. It grants no provider audience/thumbprint update
or deletion. Any role/provider cleanup, detach/delete-policy or rollback deletion
needs a separate exact-object approval after proving no workload uses it.

Additional phase-specific permissions to be reviewed against the actual plan:

| Purpose | Required action scope / boundary |
|---|---|
| CSI add-on | `eks:DescribeAddonVersions`, `DescribeAddonConfiguration`, `DescribeCluster`, `ListAddons`, `DescribeAddon`; later `CreateAddon` on the exact cluster and approved add-on ARN scope, `UpdateAddon` only if specifically planned; EKS tag reads/writes only on that add-on. Do not grant cluster/nodegroup delete or identity cleanup. |
| CSI runtime | Source-referenced EBS CSI managed policy on the exact CSI role. Read actual default EBS KMS key with `ec2:GetEbsDefaultKmsKeyId` / `GetEbsEncryptionByDefault`; confirm KMS policy/grants. If customer-managed EBS key is selected, request key-scoped cryptographic permissions plus `kms:CreateGrant`, `ListGrants`, `RevokeGrant` constrained by `kms:GrantIsForAWSResource=true`. Key ARN remains unresolved; no wildcard decrypt grant is prepared. |
| Builder runtime | `ecr:GetAuthorizationToken` on `*`; `DescribeImages`, `BatchCheckLayerAvailability`, `CompleteLayerUpload`, `InitiateLayerUpload`, `PutImage`, `UploadLayerPart`, `BatchGetImage`, `GetDownloadUrlForLayer` only on `arn:aws:ecr:us-east-2:227281812993:repository/lesson-7-django`. Publishing still needs its own approval. |
| ESO runtime | `secretsmanager:DescribeSecret`, `GetSecretValue` only for approved app/signing/GitOps/admin secret ARNs; `kms:Decrypt` only on actual necessary keys with `kms:ViaService=secretsmanager.us-east-2.amazonaws.com`. Actual non-master ARNs are missing; do not attach wildcard access. Master access is limited to approved bootstrap path, never web workload. |
| Secret provisioner | For actual approved names/ARNs: `CreateSecret`, `PutSecretValue`, `DescribeSecret`, tagging, and necessary key-scoped `GenerateDataKey`/`Decrypt`; `UpdateSecretVersionStage` only for reviewed rotation/recovery. No secret deletion or signing-key reset. Names/keys and issued Git tokens must be selected before making this an attachable exact policy. |
| Kubernetes administration | Freeze: get/patch only named `argocd/django-gitops`. Later review CSI/ESO chart RBAC/CRDs, namespace-scoped deployments/SA/rolebindings, gp3 SC, Jenkins PVC, restore ConfigMap/Job and exact ESO target Secrets. Do not reuse runtime verifier read-only RBAC for administration. No wildcard cluster-admin grant is requested. |

These requests name intended actions; they do not claim all writes have been
allowed or that simulations override SCPs/boundaries/key policies. Any AWS-managed
RDS key policy is not a customer-editable key-policy remediation target. The
actual secret and EBS key permissions need platform/key-owner confirmation.

### A3 — backend migration access

[backend-migration-access-request.json](authorization/backend-migration-access-request.json)
scopes state Get/GetVersion/Put to the four exact keys, native lock lifecycle to
their `.tflock` objects, bucket metadata/list/version reads and legacy table lock
access to `terraform-locks`. There is **no state-object deletion,
DeleteObjectVersion or bucket/IAM administration grant**. Bucket-wide listing is
read-only and deliberately supports discovery of unknown active state keys.
Granting access does not authorize a migration. Validate actual locks; never
delete an unexplained lock. Readiness evidence does not prove Put/Delete access.

Reference constraints were checked against the official
[SCP guidance](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html),
[source-referenced CSI managed policy](https://docs.aws.amazon.com/aws-managed-policy/latest/reference/AmazonEBSCSIDriverPolicy.html)
and [EKS CSI/KMS prerequisites](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html).

## 5. Deployment phase contracts and recovery checkpoints

The following rows are independent execution approvals. Each needs its actual
saved plan/manifest hashes, current versions, operator, reviewer, window, costs,
health baseline and exact recovery scope. None is granted by this document.

| Phase | Precise proposed scope and dependencies | Risk / recovery checkpoint / expected evidence |
|---|---|---|
| R0 — review/preparation | Review package; resolve A1 read access; authorize M0 offline-only rehearsal separately. No live resource writes. | Complete consolidated/retirement plans and rollback rehearsal are required before M1 review. Current owner plans alone are insufficient. |
| F — freeze/recovery capture | Approved Argo patch, Jenkins quiet-down/drain, Git/CI/operator freeze and a consistent encrypted Jenkins/state/DB recovery capture. | No restart. Require queue/operation/write-freeze proof and recoverable off-machine backups. Capture existing GitOps revision and protect legacy PostgreSQL emptyDir data. Failure leaves writers frozen or returns only separately reviewed safe controls. |
| N — state-observation normalization | Optional separately reviewed refresh-only state writes for the exact 15 disposed observations, no resource mutation. | Changes versions/serials and expires old plans. Dynamic PITR may recur; regenerate and re-review instead of suppressing guard failures. Never approve the rejected deletion plan. |
| M1 — ownership only | Complete M0 and accepted guard evidence, fresh versions and F active. Transfer 19/10/10 instances in the exact map, preserve six originals and seven retained lesson-5 resources. | Non-atomic ownership gaps; enforce section 3 rollback. No infrastructure/Helm/SQL/tag changes. Evidence: 45/7/0/0 counts, exact IDs, exclusive owners, no managed writes and unchanged health. |
| P02 — security | Separate scoped hardening plan after M1: retained rotating KMS key, in-place endpoint/encryption association, ECR immutable tags, disable auto public IP on three existing public subnets. | Private-runner DNS/routing/TLS/RBAC proof required. KMS association is one-way; retain key/grants and never revert to continuity profile afterward. Endpoint recovery requires actual approved restricted CIDR, not open public fallback. No RDS/Helm/node replacement. |
| P03 — CSI/IRSA/storage | A1/A2 resolved, M1 complete; exact issuer/subjects and actual existing provider owner. Compatible CSI **v1.68.0-eksbuild.1** observed as default for EKS 1.37 amd64/arm64. Create scoped roles/policies, CSI add-on, gp3 SC and protected `jenkins/jenkins-home` 8Gi RWO claim; annotate existing builder SA while keeping Pod Identity. | Source `prevent_destroy`, SC Retain, encrypted gp3, WaitForFirstConsumer. Preserve all Helm values/chart, RDS and current identities. Pending claim before first consumer is expected. Verify driver/node health, actual volume/KMS permissions and correct PV/AZ with approved consumer. No alternate kubectl owner. |
| P04 — ESO/secrets | After actual ARNs/key decisions: ESO chart **2.15.0**, source-scoped ESO role, secret provisioning via secure channel; app `{username,password}`, signing `{secret_key}`, GitOps `{read_token,push_token}`. | Do not print values or provision through Terraform/Helm CLI values. Preserve stable signing key/prior valid versions. Check ownership before ESO adoption of manual Secrets. Require exact SecretStore/ExternalSecret Ready and controlled workload access; metadata alone is insufficient. No Jenkins restart/application sync. |
| P05 — Jenkins recovery/cutover | Approved consistent backup and off-cluster copy; real backup PVC, scanned recovery image digest and restored PV/AZ. Use `render-jenkins-restore.py` only with actual inputs; restore fresh `restored/` as UID 1000, attest jobs/plugins/credential recovery before `jenkins_restore_verified=true`. Clear only Jenkins continuity values; retain Argo/Application freeze. | Ephemeral current home makes first restart high risk. Recovery-image build/publication must precede restore and not depend on Jenkins being recovered. Preserve old home/backups/retained PV; no empty-home rollback. Evidence: exact PVC/PV/AZ, backup hash and successful restored credential/job functionality. Later pod-replacement persistence proof needs separate disruption approval. |
| P06 — CI/artifacts/GitOps | Real controller syntax/plugin validation; build/scan app/CI images, SBOM/digests, reviewed advisory dispositions; source/ECR publishing approval. First `DEPLOY=false`, `PUBLISH_GITOPS=false`. Later separately authorized `PUBLISH_GITOPS=true`, `DEPLOY=false` while sync frozen, then review rendered exact revision. | No rollout or blind branch replacement. Freeze GitOps HEAD against concurrent writes. Preserve old digests/revisions; existing working identity remains until measured transition. Missing Docker/built-image evidence still blocks final artifacts. |
| P07a — database | Separate existing-schema ownership/grants/role/TLS/audit review and approved SQL/recovery plan for neoversity-final-db; no destructive fresh bootstrap assumptions. | PITR/snapshot recovery must be demonstrated; image rollback cannot undo SQL. Preserve unrelated databases and legacy PostgreSQL data. Do not run SQL merely because a hook exists. |
| P07b — application | Review exact published GitOps revision, canonical Applications 0.2.0 and deliberate release of Argo/Application overrides. Enable sync only after P07a approval where needed. Wave -3 ESO Ready; optional authorized -2 bootstrap; -1 migration hook; 0 app rollout. | Keep pruning **false**. Verify actual digest/revision, positive ready replicas, DB role/TLS/schema. Disable one-time bootstrap under reviewed cleanup. Never bypass failed hooks; application rollback requires DB compatibility. |
| P08/P09 — acceptance/rehearsal | Separately approved scaling/load/pod-replacement tests; independent distinct environment and cleanup/submission. | Existing RDS is never a teardown target. Preserve snapshots/PVs/backend/KMS/recovery until dependents retired. Runtime G01–G20 evidence, official rubric and clean deployment remain required. |

The storage YAML is a render for review only. Terraform remains its sole
proposed owner; **do not kubectl apply it**. The reviewed phase input file is not
tfvars and intentionally leaves unverified ARNs, recovery-image/backup-claim
inputs and restore attestation unresolved. No dummy identifiers are substituted.

## 6. Single phase-specific approval checklist

Every authorization must record approver/operator, exact artifact hashes,
state versions, source/frozen-chart manifest, time window and rollback scope.
Any changed state version, source/input/chart hash, critical health condition,
GitOps revision or freeze precondition expires the affected approval. Review
freeze resourceVersion immediately before its proposed patch. Do not sign a
blanket approval or treat a conditional later phase as permission to execute.

| Signoff | What may be approved together | Preconditions / separate boundary |
|---|---|---|
| [ ] R0 / A1 | Independent artifact review, exact OIDC read request and M0 **offline-only** rehearsal | No live state/resource writes; org administrator controls SCP response. Complete resulting consolidated/retirement plans before live M1 approval. |
| [ ] F | Coordinated Argo/Jenkins/Git/CI/operator freeze plus consistent recovery capture within one window | Named writer acknowledgements, exact guarded patch, no active operations, backup/operator recovery plan. No controller restart, state transfer or SQL included. |
| [ ] N | All four independently accepted refresh-only normalization plans | State-only effects reviewed; immutable backups; no resource mutations. Versions change: subsequent M1 plans need regeneration and new review. Not implied by R0/F. |
| [ ] M1 | M1a–M1c ownership batches under one coordinated freeze and approved stop/rollback checkpoints | M0 complete, strict guard satisfied, fresh exact versions/45-instance target and retained-source plans, two reviewers. Existing RDS/monitoring untouched. No hardening/Helm changes bundled. |
| [ ] P02 | The narrowly allowlisted security changes | Independent irreversible-KMS/private-access approval. No identity/storage/cutover/database changes bundled. |
| [ ] A2/P03 | Exact IRSA/CSI role/policy/add-on, builder SA annotation, gp3/retained claim and approved provisioning proof | SCP/provider ownership, actual effective IAM/KMS access, current compatibility and plan review. Preserve old identity/Helm/RDS. Cannot include Jenkins restart or identity deletion. |
| [ ] P04 | ESO install, scoped identity and exact secret provisioning/reconciliation | Actual secret/key ARNs, tokens and Secret ownership reviewed. No signing-key reset or SQL; no automatic adoption of existing working Secrets. |
| [ ] P05 | Jenkins downtime/quiesced backup, approved restore Job and storage cutover in one recovery window | Verified consistent backup, image/PVC/PV/AZ and functional restore before first restart. Argo remains frozen; application/database untouched. |
| [ ] P06a | Reviewed source/ECR artifact publication and build-only CI | Actual scanned images/digests/advisory dispositions and publishing authorization. No GitOps push or rollout. |
| [ ] P06b | Exact reviewed GitOps publication while sync stays disabled | Exact base/revision/chart diff approved; no rollout or pruning permission. |
| [ ] P07a | Exact DB ownership/grants/schema SQL and its specific recovery actions | Independent DB authorization, proven recovery and compatibility; not bundled with Jenkins or state migration. |
| [ ] P07b | Exact application sync/hooks and approved rollout | P07a where required, ESO Ready, frozen reviewed GitOps HEAD, legacy data preservation. Pruning remains false; deletion requires another explicit approval. |
| [ ] P08/P09 | Individually scoped runtime tests, distinct clean deployment, eventual teardown/publication | Separate disruption/cost/data-retention/submission approvals; never cleanup of existing infrastructure by implication. |

## 7. Exact remaining external and approval blockers

1. **External organization permission:** provider discovery/Get and effective
   OIDC/IRSA permissions remain SCP-blocked. The application operator cannot
   resolve an explicit organization deny by editing local policies.
2. **Required authorization:** M0 offline state-transfer/rollback rehearsal is
   prohibited until separately approved. Therefore consolidated-target and
   source-retirement plans cannot honestly be supplied as completed artifacts.
3. **Independent review/state-write boundary:** all 15 refresh observations need
   acceptance; strict guards currently fail on drift. Normalization, if chosen,
   is a separately approved state write, followed by new plans and version review.
4. **External operational evidence:** actual writer inventory/acknowledgements,
   authenticated Jenkins job/queue control, private-runner access, recovery
   operators, encrypted off-machine backups and consistent Jenkins restore proof
   are still missing. No private runner or new backup was invented here.
5. **Unprovisioned inputs:** actual app/signing/GitOps secret ARNs/key decisions,
   default EBS key/grant verification, recovery image/backup claim/PV/AZ and
   built/scanned application/CI artifacts remain unresolved. Resolve under their
   phase-specific approvals; no wildcard secret/key permissions or placeholder
   restore manifests are ready for execution.

**Review conclusion:** the four current-owner plan sets, drift dispositions,
frozen-chart proof, exact migration map, guarded freeze patch, scoped administrator
requests and phase contracts are prepared. Execution remains blocked at the
explicit boundaries above. No approval, state transfer or deployment occurred.
