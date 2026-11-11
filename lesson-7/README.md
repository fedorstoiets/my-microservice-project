# Neoversity DevOps — Homework 7: Terraform EKS + ECR + Helm

Author: Fedor Stoietskyi · AWS account used for lab: 227281812993 · Region: `us-east-2`.

## Architecture and scope

- **Same VPC as lesson-5**: `data.terraform_remote_state.lesson5` reads the existing S3 state and uses its VPC and public/private subnet IDs. It does **not** create a second VPC. The reference source files in `modules/vpc` and `modules/s3-backend` are included to match the requested folder tree; they are **not instantiated** and remain owned by the `lesson-5` Terraform state.
- **EKS**: AWS-managed Kubernetes control plane, IAM roles, and two `t3.medium` AMD64 managed worker nodes in private subnets, using the lesson-5 NAT gateway. EKS picks its current default supported version.
- **ECR**: private `lesson-7-django` repository with scan on push.
- **Helm**: Django `Deployment`, `Service` of type `LoadBalancer`, `ConfigMap` through `envFrom`, HPA 2–6 pods at CPU target 70%. Metrics Server is installed separately via Helm.
- **PostgreSQL for Homework 4 Django**: optional **coursework-only** in-cluster PostgreSQL Deployment and Service using an `emptyDir`. **Data is lost on pod rescheduling**; use RDS or a StatefulSet with EBS CSI volumes for production. Password and Django secret key are in a manually created Kubernetes Secret, NOT in ConfigMap or Git.
- **Bonus Ingress**: optional manifest gated by values, requires a separately installed ingress controller, cert-manager, DNS and a cert-manager ClusterIssuer; the chart alone does not provide TLS.

### Project layout

```
lesson-7/
  main.tf, backend.tf, outputs.tf, backend.hcl.example, terraform.tfvars.example
  modules/s3-backend/       # reference copy of lesson-5; not instantiated
  modules/vpc/              # reference copy of lesson-5; not instantiated
  modules/ecr/              # active ECR module
  modules/eks/              # active EKS + IAM + managed workers
  charts/django-app/Chart.yaml, values.yaml
  charts/django-app/templates/deployment.yaml, service.yaml, hpa.yaml, configmap.yaml
  charts/django-app/templates/postgresql.yaml, ingress.yaml, _helpers.tpl
  scripts/prepare-config.sh, check-prereqs.sh, push-image.sh, deploy-helm.sh, check.sh, cleanup.sh
```

## Before anything: AWS costs and prerequisites

**EKS is NOT free.** EKS standard-support control plane costs around $0.10/hour, plus EC2 worker nodes, NAT gateway, Elastic IP, a public load balancer, EBS and traffic costs. This can exceed **several USD per day**. Use your own authorized AWS account, enable a budget alert, and schedule time for cleanup immediately. Do not deploy merely to validate code.

**Do not run `terraform destroy` for lesson-5** while lesson-7 EKS depends on that VPC. If lesson-5 VPC/NAT/ECR was deleted after its homework, restore lesson-5 first using its own S3 state, e.g. `cd ../lesson-5 && terraform init -backend-config=backend.hcl && terraform plan && terraform apply`, then return here. Check the planned costs and *do not delete lesson-5 state bucket*. Terraform lesson-7 has its own distinct S3 state key; it reuses the same bucket.

Requires Terraform >= 1.14, AWS CLI 2, Docker Buildx, Helm 3, kubectl, an AWS login with permissions for EKS/ECR/IAM/EC2, and existing lesson-5 VPC, six subnets, S3 state bucket and working NAT. On the established WSL2 arm64 machine build an `linux/amd64` image for the `t3.medium` nodes.

## Step 1 — Check credentials and original VPC

```bash
cd ~/Neoversity/my-microservice-project/lesson-7
aws login --remote --region us-east-2  # if session expired
export AWS_REGION=us-east-2
# Terraform 1.14 may not understand aws login cached credentials:
eval "$(aws configure export-credentials --format env)"
aws sts get-caller-identity
bash scripts/check-prereqs.sh
bash scripts/prepare-config.sh
```

Never commit temporary AWS credentials, access keys, backend.hcl, terraform.tfvars or state files.

## Step 2 — Initialize and deploy infrastructure

```bash
terraform init -backend-config=backend.hcl
terraform fmt -check -recursive
terraform validate
terraform plan -out=eks.tfplan
terraform show -no-color eks.tfplan | tail -45
# Review AWS charges and ensure NO lesson-5 VPC/backend destruction.
terraform apply eks.tfplan
terraform output
aws eks update-kubeconfig --name neoversity-lesson-7 --region us-east-2
kubectl get nodes -o wide
```

If credentials expire, re-run `aws login` + export. `kubectl` authentication uses AWS CLI; check `aws eks get-token` works. Terraform-managed EKS creation can require IAM create-role and pass-role permissions not granted by all classroom AWS projects.

## Step 3 — Push the REAL Django app from Homework 4 to ECR

The root of this GitHub repository contains the Dockerfile and Django source from lesson-4. **Do not build from `lesson-7/`**. Script uses repository root as Docker build context and produces AMD64 image compatible with `t3.medium` instances:

```bash
bash scripts/push-image.sh
aws ecr describe-images --repository-name lesson-7-django --region us-east-2
```

For image pulls, node IAM role has `AmazonEC2ContainerRegistryPullOnly`. AWS worker nodes are private, so NAT from lesson-5 is required unless you configure VPC endpoints.

## Step 4 — Kubernetes Secret, ConfigMap, Helm

Non-sensitive Homework-4 variables are in `charts/django-app/values.yaml` -> `ConfigMap`: `DJANGO_DEBUG`, `DJANGO_ALLOWED_HOSTS`, `POSTGRES_DB`, `POSTGRES_USER`, `POSTGRES_HOST`, `POSTGRES_PORT`. Django secret key and PostgreSQL password **must not be committed**. The following prompts for input interactively without echoing the password:

```bash
aws eks update-kubeconfig --name neoversity-lesson-7 --region us-east-2
kubectl create namespace neoversity --dry-run=client -o yaml | kubectl apply -f -
read -r -s -p 'Postgres password: ' PG_PASS; echo
read -r -s -p 'Django secret key: ' DJANGO_KEY; echo
kubectl -n neoversity create secret generic django-app-secrets   --from-literal=POSTGRES_PASSWORD="$PG_PASS"   --from-literal=DJANGO_SECRET_KEY="$DJANGO_KEY"
unset PG_PASS DJANGO_KEY
bash scripts/deploy-helm.sh
```

Helm deploy script installs Metrics Server, creates `django-app` Deployment/Service/PostgreSQL/ConfigMap/HPA, waits for readiness, and runs DB migrations in **one** Django pod. Lesson-4 entrypoint otherwise runs migrations per replica, so the Helm chart overrides it with `gunicorn`.

Verify:

```bash
helm list -n neoversity
kubectl -n neoversity get deploy,pods,service,configmap,hpa
kubectl -n neoversity describe hpa django-app
kubectl -n neoversity get deployment django-app -o yaml | grep -A6 envFrom
kubectl top pods -n neoversity     # Metrics Server may need time to collect samples
kubectl -n neoversity get svc django-app -o wide
```

Service `EXTERNAL-IP` in AWS is typically a **DNS hostname**, not a fixed numeric IP. Test `http://<LoadBalancer-DNS>/health/` and home page; DNS and provisioning may take time. The demo `POSTGRES_HOST` points to the in-cluster PostgreSQL service; it does **not** reach the Docker Compose-only `db` container.

HPA uses `autoscaling/v2` CPU utilization (70% of `resources.requests.cpu`) and targets 2–6 pods. Under load, watch `kubectl get hpa -n neoversity -w`; capacity is limited by worker nodes (max 4), which may take time to scale.

## Bonus — optional Ingress + TLS

Set `ingress.enabled=true`, `ingress.host=...`, `ingress.className=nginx`, `ingress.tls=true`, `ingress.clusterIssuer=letsencrypt-prod`. First install a compatible ingress-nginx controller and cert-manager with an appropriate ClusterIssuer; configure DNS and security. Avoid paying for both LoadBalancer service and ingress LoadBalancer unless intended. No bonus points are awarded.

## Clean up AWS immediately after demonstration

**Delete Kubernetes Service LoadBalancer before destroying EKS** so AWS can delete the associated cloud load balancer. Run:

```bash
bash scripts/cleanup.sh
kubectl -n neoversity get svc  # confirm LoadBalancer service is gone
# Check EC2 > Load Balancers in AWS console until lab LB is deleted.
terraform plan -destroy -out=destroy-eks.tfplan
terraform show -no-color destroy-eks.tfplan | tail -45
terraform apply destroy-eks.tfplan
```

ECR images can block repository deletion because `force_delete=false`. If necessary, delete the image **for the homework repository only** before destroy:

```bash
aws ecr batch-delete-image --repository-name lesson-7-django --region us-east-2 --image-ids imageTag=lesson-7
```

Lesson-7 `terraform destroy` removes **only lesson-7-managed resources (EKS/IAM/ECR)**; the original lesson-5 S3/VPC/backend are *not* owned by this state. Then use **lesson-5's documented targeted cleanup** for VPC/NAT if not needed, keeping state bucket protected. Check billing for remaining EKS, EC2, ELB, NAT and public IPv4 charges. For re-submission, redeploy before demonstrating to mentor.

## Submission

```bash
cd ~/Neoversity/my-microservice-project
git switch lesson-7
git add lesson-7
git diff --cached --stat
git commit -m 'Add EKS and Helm chart for Django deployment'
git push -u origin lesson-7
```

Link: https://github.com/fedorstoiets/my-microservice-project/tree/lesson-7
Archive: `ДЗ7_Стоєцький_Федір.zip` (source files only; no credentials/state). State explicitly in LMS whether you accept the first grade or want to refine after feedback.
