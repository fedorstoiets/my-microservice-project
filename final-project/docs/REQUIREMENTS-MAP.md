# Requirements and evidence map

`GoalDevOps.md` is the repository's canonical acceptance list. A separately
issued official Neoversity rubric was not found in the repository or connected
sources supplied for this task; its location has been requested. Therefore
coverage of every external/official criterion and a numeric grade are
**unverified**. Do not turn this mapping into a 100/100 claim.

The submission implementation reuses the existing environment. The independent
bootstrap/infra/platform workflow is checked through offline plans and does not
require migrating the existing 39 resources or creating a second cluster. The
additive existing-addons root prepares missing prerequisites without taking
ownership of existing releases. Runtime evidence must identify its actual image,
GitOps revision and source; mock plans are not clean-deployment proof.

The mentor feedback recorded in the [published README](https://github.com/fedorstoiets/my-microservice-project/blob/ef1eea3976651bbf96a3306a77f7b0ddd741e8ff/final-project/README.md#mentor-feedback-to-close-before-submission)
specifically asks for four RDS mode plans/parameter behavior, Jenkins persistence
and identity/credentials, Argo private-repository credentials, RDS injection and
migrations, and a successful build on final-project rather than lesson-8-9.
These are the implementation priorities. Original instructor rubric/message
wording is still not independently available; no numeric grade is asserted.

| Gate | Source implementation | Evidence required beyond source |
|---|---|---|
| G01 | Protected backend bootstrap, S3 locks and lockfiles | Authenticated backend init after approved bootstrap |
| G02 | Four-root source suite and format checks | Current local-validation.json |
| G03 | Infra + platform staged configurations and mocked plans | Complete real plans for both stages, no legacy dependency |
| G04 | DEPLOYMENT.md orchestration and stage boundary | Approved clean deployment logs |
| G05 | Jenkins PVC, CSI/gp3 configuration | Ready controller and Bound persistent volume |
| G06 | Argo Application, ESO health/waves | Synced/Healthy for exact desired revision |
| G07 | Pinned monitoring release | Ready Prometheus/Grafana and scrape evidence |
| G08 | ClusterIP Jenkins and documented port-forward | Actual localhost:8080 login reachability |
| G09 | TLS Argo and documented port-forward | Actual localhost:8081 UI reachability |
| G10 | Managed custom dashboard and port-forward | localhost:3000 plus numeric live dashboard metrics |
| G11 | ESO, ephemeral/write-only secrets, non-master bootstrap, TLS, migrations | Authorized SQL/deployment, RDS/schema/role/HTTP verification |
| G12 | Exact SCM, tests/scans, ECR digest, chart alignment, delivery verifier | Successful real Jenkins build, ECR digest, GitOps revision and rollout |
| G13 | HPA, CPU requests and metrics-server | Readable metrics and observed scaling under approved load |
| G14 | Retain/protected PVC, safe restore, scoped IAM/RBAC/JCasC | Quiesced backup, real restore and pod-replacement survival; IAM review |
| G15 | Strict scans, hardening, pins and dispositions | Residual finding approval/remediation and actual image scans |
| G16 | Continuity no-change guard and state inventory | Refreshed repeated drift-free live plan |
| G17 | Dependency-aware cleanup/rollback procedure | Approved disposable-environment teardown evidence |
| G18 | README + DEPLOYMENT + MIGRATION-RUNBOOK | Documentation reviewed against actual current implementation |
| G19 | Fresh-environment path with explicit dependencies | Independent clean deployment; currently explicitly blocked |
| G20 | Allowlisted reproducible archive with manifest/final guard | Reviewed clean final-project branch, pushed matching commit and final archive |

Legacy lesson deployments and historical private snapshots are baseline
evidence only. Private snapshots had 39 proposed transfers and zero duplicate
ownership candidates; fresh live ownership checks remain mandatory. The six
existing final-project resources are retained by that state.

## External requirement categories represented

Modular Terraform networking/EKS/ECR/RDS, separate backend bootstrap, PostgreSQL
configuration, Jenkins/Kaniko build and ECR push, Argo GitOps, Prometheus/Grafana,
HPA, persistence/IRSA, JCasC/private-repository credentials, smoke/security checks,
architecture/prerequisites/operations/cost/cleanup documentation, and branch/ZIP
packaging all have source implementations. Compare exact instructor wording,
required screenshots, naming, minimum versions, permitted identity mechanisms,
and cleanup expectations when the official rubric is supplied.
