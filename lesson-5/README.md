# Neoversity DevOps — Homework 5: Terraform IaC on AWS

Author: **Fedor Stoietskyi** | Branch: `lesson-5` | Region: `us-west-2` by default.

## Overview

Terraform provisions an **S3 state bucket** (versioning, SSE-S3 encryption, all public access blocked), **DynamoDB** lock table, a **VPC with 3 public + 3 private subnets**, an Internet Gateway, **one NAT Gateway**, public/private route tables, and a private **ECR** repository with scan-on-push and a same-account repository policy.

> **Costs:** A NAT Gateway and its public IPv4 address are billed while allocated, and data processing/transfer may be billed. S3, DynamoDB, and ECR may also generate charges. AWS Free Tier is not a guarantee of zero cost. Deploy only in an account you control and destroy billable resources after verification.

## Project structure

```text
lesson-5/
├── backend.tf                      # S3 remote state + DynamoDB lock + S3 lockfile
├── main.tf                         # Provider, variables, and three modules
├── outputs.tf                      # Bucket, DynamoDB, VPC, subnets, ECR outputs
├── terraform.tfvars.example        # Example values; local terraform.tfvars is ignored
├── backend.hcl.example             # Example backend values; local backend.hcl ignored
├── scripts/prepare-config.sh       # Generates unique S3 bucket and backend settings
├── modules/
│   ├── s3-backend/
│   │   ├── s3.tf                    # S3, versioning, encryption, public access block
│   │   ├── dynamodb.tf              # DynamoDB pay-per-request, LockID string key
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── vpc/
│   │   ├── vpc.tf                   # VPC, six subnets, IGW, one NAT + EIP
│   │   ├── routes.tf                # Public IGW route, private NAT route, associations
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ecr/
│       ├── ecr.tf                   # Private ECR, scan on push, repository policy
│       ├── variables.tf
│       └── outputs.tf
└── README.md
```

## Prerequisites

- Ubuntu/Debian terminal or WSL2 Ubuntu, Terraform >= 1.10, AWS CLI v2.
- An AWS account and identity authorized for the resources and remote state.
- `aws sts get-caller-identity` must work; use AWS SSO / IAM role or securely configured AWS CLI credentials. Do **not** put access keys in Git.
- Verify `us-west-2a`, `us-west-2b`, `us-west-2c` are available to the account.

## Deployment — FIRST use (critical bootstrap order)

**Problem:** Terraform cannot initialize a remote backend until its S3 bucket and DynamoDB lock table already exist. The backend itself is declared in the same root module for this assignment. Use a **two-stage bootstrap**. The initial targeted apply is a deliberate, narrowly scoped exception to ordinary Terraform practice.

```bash
cd ~/Neoversity/my-microservice-project/lesson-5
terraform version
aws sts get-caller-identity
bash scripts/prepare-config.sh
cat backend.hcl
cat terraform.tfvars

# Stage A: initialize without S3 backend, create ONLY S3 + DynamoDB.
terraform init -backend=false
terraform fmt -recursive
terraform validate
terraform plan -target=module.s3_backend -out=bootstrap.tfplan
terraform apply bootstrap.tfplan

# Stage B: move the existing local state to the now-existing S3 backend.
terraform init -migrate-state -backend-config=backend.hcl
# When asked to migrate existing state to S3, answer yes.

# Stage C: review cost and deploy VPC + ECR.
terraform plan -out=deploy.tfplan
terraform apply deploy.tfplan
terraform output
```

**Important:** `bootstrap.tfplan` and `deploy.tfplan` are ignored by Git. Do not delete `terraform.tfstate` or manually move it during migration. Back up state securely outside Git before risky changes.

## Everyday workflow after backend has been initialized

```bash
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan
terraform apply
terraform output
```

### What each module does

- **s3-backend:** Creates an encrypted, versioned, non-public S3 bucket (`s3://...`) and a DynamoDB `PAY_PER_REQUEST` table with the required `LockID` string partition key.
- **vpc:** Creates a `10.0.0.0/16` VPC, three `/24` public subnets, three `/24` private subnets, an Internet Gateway, a public route to IGW, and a private route to one NAT Gateway. **One NAT is a lab cost optimization, not a production HA pattern.** With `nat_gateway_enabled=false`, private subnets have no default Internet route and the homework NAT requirement is not met.
- **ecr:** Creates a private `lesson-5-ecr` repository, enables scan-on-push and encryption, and applies an explicitly same-account repository policy. ECR authentication still requires separate IAM authorization.

### Terraform state locking note

The assignment specifically requires **DynamoDB state locking** (`dynamodb_table = "terraform-locks"`). Terraform marks this legacy locking mechanism **deprecated**. This project sets **both** `dynamodb_table` (for grading/compatibility) **and** `use_lockfile = true` (modern native S3 locking). They both need correct AWS IAM permissions. Future production deployments should migrate fully to S3 native locking.

## Verification

```bash
terraform state list
terraform output
aws s3api get-bucket-versioning --bucket "$(sed -n 's/^bucket = "\(.*\)"/\1/p' backend.hcl)"
aws dynamodb describe-table --table-name terraform-locks --region us-west-2 --query 'Table.KeySchema'
aws ec2 describe-vpcs --filters Name=tag:Name,Values=lesson-5-vpc --region us-west-2
aws ecr describe-repositories --repository-names lesson-5-ecr --region us-west-2
```

## Cleanup and state protection

**Do not run a plain `terraform destroy` while the active backend bucket and lock table are managed by that same state.** Removing them can destroy the state that Terraform requires to finish safely. Also, S3 versioning means old state versions survive and may still generate storage charges.

Safe lab clean-up for **billable networking/ECR** while retaining the backend for future tasks:

```bash
terraform plan -destroy -target=module.vpc -target=module.ecr -out=cleanup.tfplan
terraform apply cleanup.tfplan
terraform state list
```

The target-based destroy intentionally retains the state bucket and DynamoDB table; **it is not complete teardown**. To remove the backend too, first make an encrypted secure state backup, migrate remote state to a separate safe local or temporary backend with a tested procedure, and only then remove backend resources and any old S3 object versions. If you cannot do this safely, keep the small backend resources and ask a mentor rather than deleting the state bucket in the AWS console.

For full cleanup, Terraform's standard `terraform destroy` command exists, but **must not** be used blindly against self-hosting backend resources. Check AWS Billing/Cost Explorer afterward to ensure no unwanted charges continue.

## GitHub submission

From the repository root:

```bash
git switch -c lesson-5   # only if not already on lesson-5
git add lesson-5
git commit -m "Add Terraform modules for S3, VPC, and ECR"
git push -u origin lesson-5
```

Submit `https://github.com/fedorstoiets/my-microservice-project/tree/lesson-5` and `ДЗ5_Стоєцький_Федір.zip` to LMS. The archive contains the `lesson-5` directory and no credentials or state files.
