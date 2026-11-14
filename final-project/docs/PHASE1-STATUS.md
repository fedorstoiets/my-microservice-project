# Phase 1 — Baseline & ownership audit

The previous submission (commit `5619563`) has been preserved as a baseline. The refactor work is on `final-project-v2`.

## Private evidence

The Phase 1 audit script saves original state snapshots, a duplicate-resource-ID candidate list, Jenkins recovery backup, Helm values and GitOps source snapshot under `~/neoversity-phase1-private-<UTC timestamp>/` (mode 0700). **Do not commit or upload that folder.**

## Previous Terraform ownership (until verified & migrated)

- `lesson-5`: VPC, subnets, NAT, lesson-5 ECR and supporting infrastructure.
- `lesson-7`: EKS, node group and lesson-7 ECR.
- `lesson-8-9`: Jenkins, Argo CD and Pod Identity.
- `final-project`: RDS and kube-prometheus-stack.

These descriptions must be checked against the private state ownership summary. Planned consolidation is NOT complete.

## Existing AWS limitation

The account's Organizations SCP denied `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider`. An EKS OIDC issuer URL alone does not establish an IAM provider. IRSA requires an authorized provider and role setup.

## Next

1. Review private ownership map and possible duplicates.
2. Confirm backup integrity and remote state object versioning.
3. Validate permissions for IAM, EBS CSI and Terraform imports without modifying resources.
4. Write an import/migration-by-resource plan before Phase 2.
