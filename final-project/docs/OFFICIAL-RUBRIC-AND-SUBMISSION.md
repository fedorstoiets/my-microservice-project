# Final DevOps project — official rubric and deployment evidence

**Submission branch:** `final-project-v2` (intentionally retained; the older `final-project` branch is not overwritten).

**Mentor review:** Anton Shakh, November 14, 2026: **«Роботу прийнято»** (accepted). Acceptance is documented; **100/100 has not been awarded or independently verified**.

**Verified deployment:** November 15, 2026. AWS account `227281812993`, region `us-east-2`, EKS `neoversity-lesson-7`, isolated Kubernetes namespace `goaldevops-v2-final`.

## Official marking criteria (100 points)

| Criterion | Maximum | Demonstrated | Remaining verification |
| --- | ---: | --- | --- |
| Correct AWS architecture | 20 | VPC, EKS, RDS, ECR, Jenkins, Argo CD, Prometheus and Grafana are present. Root `main.tf` calls VPC/EKS/ECR/Jenkins/Argo/RDS modules and monitoring Helm; fresh-environment Terraform is separated into bootstrap/infra/platform roots. | **The root is migration-HOLD and has not been safely applied as one independent project.** This remains the main mentor concern. |
| VPC, IAM and Security Groups | 20 | Encrypted private RDS; restricted DB role; EKS cluster; scoped ESO Secrets Manager identity; IRSA source definitions. | Full effective Jenkins builder IAM/OIDC permissions and SG review not yet evidenced. |
| Deployed AWS application with CI/CD | 30 | Jenkins SCM Build #3 passed on commit `306069e18209a92124a1a75dd9a8bbfe6607c3a1`, immutable ECR image `sha256:37b3b0311ca9f968020e4bcd207b53a3c95fe024fe5d2f2308e16bcea09d583a`; Argo CD `goaldevops-v2-final` Synced/Healthy; Django 2/2; live RDS health returned `connected:true, restricted_role:true`. | GitOps publication / continuous promotion was disabled during the verified Jenkins build; full Jenkins-to-GitOps automation not proven. |
| Monitoring and autoscaling | 20 | Prometheus and Grafana controllers Ready, custom dashboard ConfigMap present. HPA 2–6 replicas, 70% CPU target; live CPU metrics available (3% at last read). | Dashboard **live numeric charts** and observed HPA scale-out/recovery remain unverified. |
| Documentation | 10 | README, deployment guide, runbooks, Terraform/modules, source security checks, 28 regression tests and 4 Django tests passed. | Refresh screenshots and records to agree with live deployment; protect credentials. |

## Mentor feedback — concrete resolutions and caveats

1. **Unified Terraform:** Existing `final-project/main.tf` does connect `module.vpc`, `module.eks`, `module.ecr`, `module.jenkins`, `module.argo_cd`, `module.rds`, plus monitoring. The source check passed, but **no single-root real `terraform apply` was executed on this configuration**, because ownership belongs to multiple earlier Terraform states. The independent staged roots in `bootstrap/` and `deployments/` also passed source checks; their production apply is not demonstrated. Never run root apply/destroy against the existing environment or migrate state without an explicit reviewed plan.
2. **Django → RDS:** **Resolved in live isolated deployment.** PostgreSQL database `goaldevops_v2_final` uses a non-master owner `goaldevops_v2_app`, ESO-managed application credentials and RDS TLS CA. `/health/` returned `{"status":"ok","database":"postgresql","connected":true,"restricted_role":true}`. The existing production Django configuration was not modified.
3. **Jenkinsfile:** Present in the project root and `Django/Jenkinsfile` with source suite checking identical contents. Jenkins SCM Build #3 built the accepted digest.
4. **Kaniko IRSA:** Source contains scoped OIDC/IRSA configuration. A successful Jenkins build alone does not independently establish the effective live IRSA identity; check this before claiming full closure.
5. **Jenkins durability/secrets:** Live Jenkins StatefulSet mounts `jenkins-home` Bound gp3 persistent volume; credentials/jobs survived restart. ESO ClusterSecretStore and ExternalSecret were Ready. Avoid exposing tokens/admin passwords; additional replacement-survival and least-privilege tests remain separate from basic readiness.
6. **Metrics-server:** Working: HPA reports CPU metrics and 2–6 min/max configuration.
7. **Documentation/order:** `docs/DEPLOYMENT.md` documents bootstrap → infra → platform for **new** environments and existing-environment limitations. Root Terraform remains explicitly migration-HOLD rather than pretending a legacy-resource import has occurred.

## Verified November 15 runtime summary

| Check | Result |
| --- | --- |
| EKS | 3/3 nodes Ready |
| Django isolated deployment | 2/2 replicas Ready |
| Argo CD isolated app | Synced / Healthy |
| RDS | Private, encrypted, backed up, restricted DB connection healthy |
| ESO | ClusterSecretStore and ExternalSecret Ready |
| ECR digest | `sha256:37b3b0311ca9f968020e4bcd207b53a3c95fe024fe5d2f2308e16bcea09d583a` |
| Jenkins | Persistent controller PVC Bound; SCM Build #3 Success |
| HPA | min 2 / max 6; metrics API responding |
| Prometheus / Grafana | Controllers Ready; dashboard provisioned as ConfigMap, numeric UI evidence pending |
| Code validation | Terraform fmt, 5 validates, 3 strict Helm lints, Terraform tests, 28 Python regression tests and 4 Django tests passed under pinned Python virtualenv |

Evidence retained privately, outside the source ZIP: `~/neoversity-private-recovery/final-acceptance/` and `~/neoversity-private-recovery/final-execution/`. Do not add raw cloud credentials, admin tokens, plans, state files or backups to the public repository.

## Reproduce local checks

From `final-project/` in WSL:

```bash
PY="$HOME/.venvs/goaldevops-final/bin/python"
export PYTHON="$PY"
bash scripts/goaldevops-source-check.sh
"$PY" scripts/package-submission.py
cd dist && sha256sum -c final_DevOps_Стоєцький_Федір.draft.zip.sha256
```

The resulting `final_DevOps_Стоєцький_Федір.draft.zip` is a **validated source archive**, not evidence of every rubric item. The archive's `.draft` suffix is required by this repository's stricter *internal* G01–G20 final-release gate; those gates are **not the official 100-point rubric**. The mentor's stated requested submission filename is `final_DevOps_Стоєцький_Федір.zip`; do not mislabel a draft as a certified final artifact. Any instructor-facing archive should accurately identify the Git SHA/branch and proven limitations.

## Port-forward and evidence commands (read-only)

```bash
kubectl get all -n jenkins
kubectl get all -n argocd
kubectl get all -n monitoring
kubectl -n goaldevops-v2-final get deploy,hpa,pods
kubectl -n argocd get application goaldevops-v2-final

# Use separately while reviewing UIs; the actual Grafana service here is monitoring-grafana.
kubectl -n jenkins port-forward svc/jenkins 8080:8080
kubectl -n argocd port-forward svc/argocd-server 8081:443
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
```

**Cost and teardown warning:** AWS EKS nodes, NAT, EBS, RDS and monitoring incur charges. The official instructions recommend `terraform destroy` of disposable projects, but this live cluster contains shared lesson infrastructure managed by other Terraform states. **Do not run `terraform destroy` against the current root or any shared state.** A separately approved cleanup must protect backups, PVCs, RDS snapshots, and S3 state backend ordering.

## Evidence boundaries

The G01–G20 gates in `docs/GoalDevOps.md` are stricter **internal engineering controls**, not the official instructor scoring scheme. A check that is only configured or has passed simulated tests must never be reported as a verified live demonstration. A mentor-accepted project can still have remaining improvement items; only the mentor/instructor determines the numeric grade.
