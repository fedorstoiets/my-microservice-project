# Security review — open items and risk acceptance

Trivy IaC scan executed on the final-project working tree. **This scan is not clean and was non-blocking by design.** Review the adjacent sanitized evidence file for counts and finding IDs. Findings include:

- **Critical — EKS API access:** Terraform reference module permits public EKS control-plane endpoint, with no restrictive CIDR list. Confirm actual live cluster settings before editing, and preserve kubectl access. Restrict for production.
- **High — Kubernetes containers:** Django and legacy in-cluster PostgreSQL charts lack explicit restrictive pod/container security contexts and read-only root filesystems. Hardening requires image/runtime compatibility validation.
- **High — ECR:** reference module allows mutable tags. Use immutable versioned tags for production; confirm Jenkins publishing flow first.
- **High — EKS secrets encryption:** IaC scanner wants an explicit encryption configuration; compare against the live EKS version and AWS-managed defaults before changing existing cluster.
- **High — S3 Terraform backend:** reference module uses SSE-S3 AES256 rather than a customer-managed KMS key. State bucket access should remain restricted.
- **High — public subnet:** assigning public IPs is expected for some internet-facing infrastructure; minimize workloads placed there.

Account-level IAM **SCP denied** `iam:ListOpenIDConnectProviders` and `iam:GetOpenIDConnectProvider`. IRSA/OIDC ownership is not verified; existing Kaniko builds are using EKS Pod Identity. Preserve that operational setup unless authorized to replace it.

The verification script reports operational health, Terraform validation, and execution of the scanner. It does not assert zero security findings. Jenkins currently has no persistent volume. Do not present the system as production hardened.
