# GoalDevOps Phase 2 — migration hold

This development-branch configuration is **not ready to apply** to the live state.

- Terraform state is still owned by four remote states. 39 instances have been moved **only in private scratch copies**.
- The primary project backend remains `final-project/terraform.tfstate` and must not be overwritten with an unreviewed scratch file.
- S3/DynamoDB backend ownership stays separately managed through the legacy `lesson-5` state until a controlled bootstrap split is performed.
- Legacy provider aliases maintain historical tags during migration; later tagging changes require a separate plan.
- Django/RDS integration, Jenkins storage, IRSA, clean-environment provider bootstrap, CI/CD source alignment, and security improvements remain OPEN.
- Never run `terraform apply`, `terraform destroy`, `terraform import`, or a remote `state push` based on this draft alone.

Next gate: compare local scratch plan with this exact staged source, then prepare a resource-by-resource live migration runbook and backups.
