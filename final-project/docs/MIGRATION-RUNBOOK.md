# Existing environment: migration and rollback runbook

**Status: HOLD. This document does not authorize execution.** The root backend,
RDS address `module.rds[0]`, and monitoring address `helm_release.monitoring[0]`
remain unchanged. No state transfers, imports, applies, IAM updates, Kubernetes
cutovers, or database mutations have been performed by this remediation.

## Evidence and ownership

`evidence/historical-ownership.json` is derived from the existing private
2026-11-14T20:12:31Z backups. It contains state lineages, serials, backup hashes,
Helm versions, and a resource-by-resource address map, without state contents.
The snapshots contain 52 managed instances: lesson-5 26, lesson-7 10,
lesson-8-9 10, final-project 6. There are zero duplicate type/ID candidates in
those snapshots. The proposed continuity transfer has 39 instances. The six
already owned by final-project, including RDS and monitoring, stay there.
Backend resources and the unrelated lesson-5 ECR remain with their old owner.
These observations are historical and cannot certify current ownership.

Current STS authentication is unavailable (`evidence/aws-preflight.json`). Stop
before planning live migration until authentication and required reads work.
The official Neoversity rubric has not been located separately from GoalDevOps;
obtain it and reconcile `REQUIREMENTS-MAP.md` before final acceptance.

## Read-only preflight

1. Record the reviewed source commit and hash of every dirty source file.
   Do not assume HEAD describes this working tree. Keep backups outside Git,
   with mode 0700 directories and 0600 files, encrypted off-machine copies,
   and a named recovery operator. Do not upload raw Terraform plans/state.
2. Authenticate using the organization's approved login flow. Confirm the
   expected AWS account, region, EKS cluster endpoint and kube context privately.
   Do not print exported credentials. Verify OIDC, EBS CSI, Secrets Manager,
   S3 versioning/locking, and private network access using read-only APIs.
3. Refresh all four states, pinning each S3 object VersionId:

   ```bash
   python3 scripts/state-inventory.py --bucket "$STATE_BUCKET" --region "$AWS_REGION" --discover \
     --output "$PRIVATE_NEW_BACKUP_DIRECTORY"
   ```

   Supply the actual bucket from the existing backend, not an invented name.
   The tool reads immutable versions, hashes backups, checks for concurrent
   state changes, and reports duplicate ownership candidates. It never writes
   remote state. A duplicate, missing version, deposed instance, unexpected
   address, or owner mismatch blocks migration. Include nonstandard active state
   keys explicitly with --keys; discovered archived copies need owner review and
   must not be confused with active owners. If bucket discovery is denied, obtain
   an authoritative complete state-owner inventory before claiming exclusive
   ownership. Review IDs privately; service
   names alone are not globally unique identities.
4. Establish an explicit write-freeze covering all four owners, scheduled CI,
   operator terminals, Argo auto-sync and Jenkins jobs. Changing controller
   settings to enforce the freeze is itself a separately authorized operation.
   S3 lockfiles and legacy DynamoDB locks do not mutually coordinate clients:
   document every client/version and ensure compatible locking or a verified
   external freeze. Never disable locking or force-unlock an unexplained lock.
5. Verify Jenkins application-consistent recovery material. The preserved
   running-controller tarball is only a baseline, not proof of consistency.
   `python3 scripts/jenkins-home.py "$BACKUP_ARCHIVE"` validates paths and
   required key files without exposing them. Rehearse local restoration to a
   new private directory, verify plugins/jobs/credentials offline, and record
   the backup checksum. A new quiesced backup needs separate authorization.

## Continuity rehearsal (private scratch copies only)

Create a disposable source copy and local-backend state copies outside this
repository. The production S3 key must never receive a scratch file. Preserve
provider aliases `legacy5`/`legacy7` and historical tags. Refresh the address map
from the new inventory and reconcile it with the appendix below.

Use `scripts/continuity-values.py` with the private state backups to produce
private `*.tfvars.json` inputs containing the four deployed Helm values lists.
It rejects duplicate releases and Helm set overrides that require extra review.
Pass those inputs to the ownership-only plan; the generator explicitly selects
security_profile=continuity. Preserve their deployed Helm values for the separate
hardening plan while explicitly selecting hardened and proving private-runner access. They keep the proposed Jenkins
persistence/plugin/branch changes, Argo health customization and Application
chart changes out of the ownership transfer. Do not print those inputs.

Do not combine a Helm chart-content change with migration: a local chart at the
same version can still render different manifests. For the continuity source
copy, restore the deployed Applications chart from the recorded source commit
or private GitOps/source backup and verify its content against the deployed
Helm manifest privately. The version number by itself is insufficient. If that
artifact cannot be reconstructed, migration remains blocked; do not hide the
change using ignore_changes.

The rehearsal must preserve each resource's physical ID and provider binding,
retain final-project's original RDS and monitoring instances, and leave every
retained legacy resource in exactly one source state. Execute state-editing
rehearsal commands only after explicit approval covering offline state edits.
No such commands are embedded in an automatically executable helper here.

Generate a complete private plan, convert it to private JSON and run:

```bash
python3 scripts/check-plan.py "$PRIVATE_PLAN_JSON" --expected-managed-count "$REVIEWED_TARGET_COUNT"
```

The check rejects create/update/delete/replacement, incomplete or deferred
plans, and refresh drift. Human review must additionally compare outputs,
provider bindings, state lineages/serials, old-owner retirement plans and all
physical IDs. A mocked Terraform test is not continuity evidence.

## Approval packet and live transfer (separate explicit authorization required)

Submit: source hashes, all four fresh object versions/lineages/serials, complete
address/ID/provider map, private backup verification, write-freeze proof,
no-change continuity plans for source and destination, rollback rehearsal,
operator assignments, cost implications and a precise list of intended writes.
Two operators must review the packet. Any new version or source change expires
approval and requires preflight/review again.

Live cross-state changes are not atomic. Under the verified freeze, remove the
approved instances from source ownership before adding them to the destination;
never create simultaneous active ownership. The temporary unmanaged interval
must have no applies or controller reconciliations. Retain backend resources
and unrelated ECR in lesson-5. Preserve the six existing final-project instances
and the destination lineage. Compare fresh versions before every write, use
normal locking, and stop on conflicts. Do not use force pushes, S3 overwrite,
imports of already-owned resources, or serial manipulation to bypass a conflict.

After each approved step, pull all affected states read-only, regenerate the
ownership map, compare physical IDs/counts and plan with refresh. Release the
freeze only after zero duplicate ownership, zero unintended managed changes,
healthy unchanged workloads and second-operator signoff. State migration alone
must not restart Jenkins, alter RDS, or change the monitoring Helm release.

## Rollback

Keep the freeze on any discrepancy. Compare current lineages, serials and S3
versions against the packet and identify which writes completed. Stop every
apply. Remove transferred destination ownership before restoring source
ownership, using a reviewed reconstruction from current states plus verified
backups. Retain the original destination RDS/monitoring instances throughout.
Do not blindly restore an older S3 version, decrease serials or force-push an
old backup. A rollback write needs explicit authorization and second review.
Re-run all ownership and no-change checks before ending the freeze. If rollback
cannot prove exclusive ownership, retain the freeze and escalate to operators.

## Changes after continuity

Use a new plan and separate authorization for each of: IAM/OIDC/CSI; platform
secrets and repository credentials; Jenkins PVC restore/cutover; Application
chart alignment; database role/schema changes; security settings; monitoring
upgrades. Do not apply the new-environment staged roots to existing lesson
resources. Splitting the migrated root into stages would be a second, separately
reviewed state transfer. The staged roots implement a distinct fresh environment.

## Historical address map

The following is a proposal derived from private snapshots, not live approval.

| Source state | Address | Disposition |
|---|---|---|
| final-project | `helm_release.monitoring[0]` | retain_in_final_state |
| final-project | `module.rds[0].aws_db_instance.standard[0]` | retain_in_final_state |
| final-project | `module.rds[0].aws_db_parameter_group.standard[0]` | retain_in_final_state |
| final-project | `module.rds[0].aws_db_subnet_group.main` | retain_in_final_state |
| final-project | `module.rds[0].aws_security_group.database` | retain_in_final_state |
| final-project | `module.rds[0].aws_vpc_security_group_ingress_rule.from_sg["sg-0072c2bc38f9d15bc"]` | retain_in_final_state |
| lesson-5 | `module.ecr.aws_ecr_repository.main` | retain_legacy_owner |
| lesson-5 | `module.ecr.aws_ecr_repository_policy.main` | retain_legacy_owner |
| lesson-5 | `module.s3_backend.aws_dynamodb_table.locks` | retain_legacy_owner |
| lesson-5 | `module.s3_backend.aws_s3_bucket.state` | retain_legacy_owner |
| lesson-5 | `module.s3_backend.aws_s3_bucket_public_access_block.state` | retain_legacy_owner |
| lesson-5 | `module.s3_backend.aws_s3_bucket_server_side_encryption_configuration.state` | retain_legacy_owner |
| lesson-5 | `module.s3_backend.aws_s3_bucket_versioning.state` | retain_legacy_owner |
| lesson-5 | `module.vpc.aws_eip.nat[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_internet_gateway.main` | review_transfer |
| lesson-5 | `module.vpc.aws_nat_gateway.main[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_route.private_outbound[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table.private` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table.public` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.private[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.private[1]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.private[2]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.public[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.public[1]` | review_transfer |
| lesson-5 | `module.vpc.aws_route_table_association.public[2]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.private[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.private[1]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.private[2]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.public[0]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.public[1]` | review_transfer |
| lesson-5 | `module.vpc.aws_subnet.public[2]` | review_transfer |
| lesson-5 | `module.vpc.aws_vpc.main` | review_transfer |
| lesson-7 | `module.ecr.aws_ecr_repository.main` | review_transfer |
| lesson-7 | `module.ecr.aws_ecr_repository_policy.main` | review_transfer |
| lesson-7 | `module.eks.aws_eks_cluster.main` | review_transfer |
| lesson-7 | `module.eks.aws_eks_node_group.main` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role.cluster` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role.nodes` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role_policy_attachment.cluster` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role_policy_attachment.nodes["AmazonEC2ContainerRegistryPullOnly"]` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role_policy_attachment.nodes["AmazonEKSWorkerNodePolicy"]` | review_transfer |
| lesson-7 | `module.eks.aws_iam_role_policy_attachment.nodes["AmazonEKS_CNI_Policy"]` | review_transfer |
| lesson-8-9 | `kubernetes_namespace_v1.argocd` | review_transfer |
| lesson-8-9 | `kubernetes_namespace_v1.jenkins` | review_transfer |
| lesson-8-9 | `module.argo_cd.helm_release.applications` | review_transfer |
| lesson-8-9 | `module.argo_cd.helm_release.argocd` | review_transfer |
| lesson-8-9 | `module.jenkins.helm_release.jenkins` | review_transfer |
| lesson-8-9 | `module.kaniko_identity.aws_eks_addon.pod_identity` | review_transfer |
| lesson-8-9 | `module.kaniko_identity.aws_eks_pod_identity_association.kaniko` | review_transfer |
| lesson-8-9 | `module.kaniko_identity.aws_iam_role.kaniko` | review_transfer |
| lesson-8-9 | `module.kaniko_identity.aws_iam_role_policy.ecr_push` | review_transfer |
| lesson-8-9 | `module.kaniko_identity.kubernetes_service_account_v1.builder` | review_transfer |

The unified current execution program is EXECUTION-PLAN.md. It separates Jenkins
recovery from Argo/Application release, and keeps automatic pruning disabled
until legacy resource/data preservation has been independently reviewed.
