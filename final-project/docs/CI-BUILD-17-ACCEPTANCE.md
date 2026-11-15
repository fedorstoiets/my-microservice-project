# CI acceptance update — November 15, 2026

This document supersedes earlier statements that the submitted pipeline
had never successfully built an image.

## Verified

- Jenkins job `django-ecr-gitops`, Build #17: SUCCESS using Replay.
- Four Django tests and 28 regression tests: PASS.
- Helm lint: PASS.
- Strict source security scan: PASS, zero HIGH/CRITICAL findings.
- Kaniko built and published the application image to ECR.
- ECR image digest:
  `sha256:06e62026efa3aea157578980095e1c6e3c1a3b6aac33d788b6aab6bd8f66b32e`
- Published image scan: no vulnerabilities reported.
- Jenkins console evidence preserved outside Git.
- Separate isolated Argo CD deployment: Synced/Healthy, PostgreSQL
  migrations completed, HTTP `/health/` returned 200.
- Live baseline Django and Argo CD were healthy after source validation.
- The final source regression suite passed 28/28 tests.

## Critical acceptance boundaries

Build #17 used Jenkins Replay and an uncommitted source snapshot.
It did **not** exercise checkout of a committed final-project revision.

The isolated Argo CD deployment and Jenkins Build #17 were separate
verifications. They do not prove uninterrupted SCM-to-GitOps delivery.

During Build #17, GitOps publication and deployment were disabled.

The isolated database health result reported `restricted_role: false`.

Live Jenkins persistent storage, ESO reconciliation, full least-privilege
database access, controlled HPA scaling, fresh-environment deployment,
no-drift confirmation and full recovery remain outstanding.

The original independent instructor rubric has not been obtained.
Do not claim 100/100 or G01-G20 completion.

## Next acceptance action

Execute the committed-source Jenkins pipeline through normal SCM
checkout with publication/deployment disabled, verify the same
tests/build/image scan, and preserve the actual Git commit SHA.

Production changes require separately reviewed authorization.
