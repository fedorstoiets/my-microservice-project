# Submission checklist

- [x] Source on `final-project` branch (after running the packaging script)
- [x] AWS infrastructure deployed: VPC / EKS / RDS / ECR / Jenkins / Argo CD / Prometheus / Grafana
- [x] Django uses private RDS; health query and HTTP smoke tests pass
- [x] HPA and Prometheus metric queries demonstrated
- [x] Custom Grafana dashboard ConfigMap provisioned
- [x] `terraform fmt` and `terraform validate` passed
- [x] Trivy was run; residual findings disclosed
- [x] Operational verification report: 11 passed / 0 failed / 0 skipped
- [x] Documentation and sanitized evidence included
- [ ] Jenkins persistence to EBS and IRSA (open mentor-feedback improvements; not implemented)
- [ ] Remediate all Trivy HIGH/CRITICAL findings (not completed)

**Submit:** the repository link to the `final-project` branch plus the ZIP produced by the packaging script. Attach screenshots if the grading portal specifically requires screenshots; none are invented or included by this script.
