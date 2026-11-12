# Neoversity Homework 8–9 — Jenkins + Kaniko + Terraform + Argo CD

## Architecture

`lesson-8-9 branch (Django Dockerfile) -> Jenkins Kubernetes Agent (Git + Kaniko) -> Amazon ECR (SHA tag) -> separate GitOps repository main (Helm values.yaml) -> Argo CD auto-sync -> EKS Django Deployment`.

Uses **existing** lesson-7 EKS `neoversity-lesson-7`, existing lesson-5 VPC, existing ECR `lesson-7-django`, and existing S3 state bucket. No duplicate clusters/VPC/ECR are created. Separate Terraform state key: `lesson-8-9/terraform.tfstate`. Terraform installs Jenkins and Argo CD Helm releases and an Application Helm chart. Kaniko uses EKS Pod Identity and scoped ECR IAM permissions; it never receives static AWS keys.

## Requirements and cost

AWS account 227281812993, region us-east-2, EKS cluster ACTIVE and worker nodes Ready; existing ECR repo and Dockerfile from lessons 4/7. `aws`, `kubectl`, `helm`, `terraform`, `git`, `gh` installed. AWS credentials must be refreshed before deployment. EKS/EC2/NAT plus storage (if enabled) have ongoing charges. Jenkins persistence is disabled **for coursework only**; restarting controller loses configuration/state and manually added GitHub credential. This is not a production configuration. PostgreSQL uses ephemeral storage.

## One-pass setup (two repositories)

1. In Ubuntu at `~/Neoversity/my-microservice-project`, check out/create `lesson-8-9`, unzip the provided folder and ensure Django Dockerfile plus lesson-7 are included. GitOps repo must be public for the zero-extra-credential Argo CD demonstration; do not commit passwords to it.
2. Install GitHub CLI if needed (`sudo apt-get update && sudo apt-get install -y gh`), then `gh auth login` with GitHub authorization. Create separate GitOps repo in one command: `bash lesson-8-9/scripts/setup-gitops.sh`. Verify `https://github.com/fedorstoiets/neoversity-django-gitops` exists and `main` contains `charts/django-app/values.yaml`.
3. Make sure the lesson-7 secret `django-app-secrets` still exists in namespace `neoversity`; reuse it without putting values in Git. If cleaned up, create secret following lesson-7 README.
4. AWS CLI login if necessary:
   ```bash
   unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_PROFILE
   aws login --remote --region us-east-2
   eval "$(aws configure export-credentials --format env)"
   ```
   This export is needed for the installed Terraform S3 backend; avoid displaying the credentials. For expired credentials refresh the login and export again.
5. `cd lesson-8-9 && bash scripts/preflight.sh && bash scripts/prepare.sh`. Inspect `deploy.tfplan`. The plan should **only** add Jenkins/Argo Helm releases, Pod Identity IAM/add-on, and Kubernetes namespaces/SA. Then `terraform apply deploy.tfplan`. If `eks-pod-identity-agent` already exists and is not managed by this state, import it instead of attempting a duplicate creation.
6. `bash scripts/post-install.sh` creates only a safe Kaniko Docker config ConfigMap and displays services. Existing lesson-7 `django-app` Helm release must be uninstalled **before** Argo takes ownership of identical Kubernetes objects. This removes temporary PostgreSQL data: `helm uninstall django-app -n neoversity`. Preserve `django-app-secrets`. Argo will create the replacement chart from Git.
7. Configure Jenkins **Secret text** credential ID `github-gitops-pat` in Jenkins UI (`Manage Jenkins > Credentials > System > Global`). Use a fine-grained GitHub PAT with **Contents: Read and write** for `neoversity-django-gitops` only. Do NOT put it into Terraform code, helm values, Git or an uploaded ZIP. Branch `main` must allow pushes from the token owner. Do not run a build before setting this credential.
8. Run Jenkins job `django-ecr-gitops` from its dashboard (created by JCasC + Job DSL). It clones source branch `lesson-8-9`, builds root Dockerfile with Kaniko, pushes immutable Git-commit tag to ECR, updates only `image.tag` in GitOps `charts/django-app/values.yaml`, commits and pushes to `main`. Argo CD polls and syncs automatically. If `gcr.io/kaniko-project/executor:v1.23.2-debug` becomes unavailable, swap to an actively supported Kaniko distribution and validate its credential-helper behavior. The old upstream Kaniko images are unmaintained.

## Access and verification

Open two separate Ubuntu terminals:
```bash
kubectl -n jenkins port-forward svc/jenkins 8080:8080
kubectl -n argocd port-forward svc/argocd-server 8081:443
```
Jenkins: `http://localhost:8080` (admin password: `kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo`). Argo CD: `https://localhost:8081` (initial password: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo`). Access only from your machine; do not publish admin UIs via public LoadBalancer.

Check:
```bash
kubectl -n jenkins get pods,sa
kubectl -n argocd get applications.argoproj.io
kubectl -n argocd get application django-gitops -o jsonpath='{.status.sync.status} {.status.health.status}{"\n"}'
aws ecr describe-images --region us-east-2 --repository-name lesson-7-django --query 'imageDetails[].imageTags' --output json
kubectl -n neoversity get deploy,pods,svc,hpa,configmap
kubectl -n neoversity get deploy django-app -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
```
Expected Argo `Synced Healthy`, new Django tag from Jenkins Git SHA, 2 Running pods, LoadBalancer HTTP 200 and HPA CPU metrics. To prove automated GitOps, make a small Django code change and commit to the source `lesson-8-9`, trigger Jenkins again, and verify new tag in GitOps main followed by Argo auto-sync.

## Jenkins Pod Identity and GitHub credentials

Terraform creates Pod Identity ECR push permissions only for the `kaniko-builder` service account in `jenkins`. The GitOps PAT is manually entered once in Jenkins Credentials. Public GitOps repo is readable by Argo without secrets. Do not make the source or Jenkins UI publicly writeable. Avoid printing bearer tokens in logs.

## Cleanup (important)

After collecting screenshots/logs and making the GitHub/LMS submission, remove the Argo CD `Application` (automated prune), application resources, Jenkins and Argo Helm releases, then Pod Identity/IAM via `terraform destroy`. Follow `scripts/cleanup.sh` cautiously; inspect chart ownership and finalizers. The script cleans lesson-8-9 only and **does not** stop EKS + NAT billing. Only after this cleanup, destroy lesson-7 EKS; finally destroy lesson-5 VPC/ECR selectively, keeping lesson-5 S3 backend and DynamoDB. Never run `terraform destroy` in lesson-5 while its backend bucket is in the same state. Preserve safe copies of outputs and logs. The local Terraform destroy plan deletes Argo applications first, followed by Argo/Jenkins releases. If a Helm finalizer blocks deletion, check the Argo Application and its dependent LoadBalancer before proceeding.

## Submission

Push `lesson-8-9` to `https://github.com/fedorstoiets/my-microservice-project/tree/lesson-8-9`, attach `lesson-8-9_Стоєцький_Федір.zip` from the committed repo (`git archive --format=zip ... lesson-8-9 lesson-8-9/`). Provide Jenkins build log, successful ECR tag, GitOps `main` commit and Argo Synced/Healthy screenshot. No bonus domain necessary.
