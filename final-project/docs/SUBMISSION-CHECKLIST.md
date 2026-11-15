# Submission checklist

- [x] Connected Terraform source, independent offline bootstrap/infra/platform path.
- [x] Existing-cluster additive CSI/IRSA/ESO/storage source; no 39-resource migration.
- [x] Five Terraform validations, 14 mocked plans, three chart lints, Python/Django tests.
- [x] Strict source scans: zero HIGH/CRITICAL; runtime/image exceptions remain separate.
- [x] Existing RDS/HTTP, Argo, 19 Prometheus targets, custom dashboard and HPA metric evidence.
- [x] Local Jenkins archive restore: 79 files and zero hash mismatches; scope is file integrity only.
- [ ] Resolve administrator OIDC SCP restriction and refresh authenticated access.
- [ ] Approve/apply additive CSI/IAM/retained storage; verify real provisioning.
- [ ] Obtain consistent complete Jenkins backup and functional recovery before storage cutover.
- [ ] Verify actual scoped secrets/IRSA, DB role/TLS and final-project pipeline build/deployment.
- [ ] Capture controlled HPA scaling and persistent Jenkins replacement survival.
- [ ] Independently review source, publish matching final-project commit without overwriting remote work.
- [ ] Final acceptance and matching final_DevOps_Стоєцький_Федір.zip with manifest/SHA256.

Existing working services and state are preserved. Source success, historical
lesson evidence and a candidate ZIP do not prove the remaining runtime boxes.
