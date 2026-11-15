# Deployment, storage, secrets and teardown

**HOLD remains active for existing infrastructure.** No live deployment is
implied by this source. This runbook describes actions to propose for separate
approval; it is not permission to execute them. Local validation is safe.

## Choose one ownership path

**Reuse the existing environment for implementation and runtime evidence.**
Use the additive root below for new prerequisites, without migrating 39 resources
or creating a second EKS cluster. The separate clean workflow remains a tested
offline reproduction path, not a successful live clean deployment. Preserve
every existing state, deployment, backup and database.

| Path | Configuration | Ownership |
|---|---|---|
| Existing additions (implementation path) | deployments/existing-addons | New prerequisites only; old owners unchanged |
| Optional existing migration | held root plus MIGRATION-RUNBOOK.md | Do not apply or transfer state without separate approval |
| Distinct clean environment | bootstrap → deployments/infra → deployments/platform → Jenkins/Argo | Separate new names and S3 keys; no adoption of lesson resources |

Never point both paths at the same physical resources. The new environment
requires names starting `goaldevops-v2-` and separate backend keys. Reusing the
same lesson identifiers or changing keys to legacy keys defeats isolation.
A deployment using a pre-existing legacy VPC is not the clean-environment test.
Use a **separate demo GitOps repository**, too. The existing live GitOps main
branch has automatic sync/pruning enabled; publishing demo charts there could
mutate the old environment even when Terraform uses new state keys.

## Existing environment additions without migration

`deployments/existing-addons/` references the actual cluster/ECR through AWS data
sources, not homework remote states. It owns only new OIDC (only if absence was
authoritatively verified), three narrowly trusted IRSA roles, scoped builder/ESO
policies, EBS CSI, gp3 Retain storage and the protected standalone Jenkins claim.
ESO installation is disabled until exact secret ARNs are provided. It does not
own EKS, VPC, ECR, RDS, Jenkins, Argo, monitoring or the existing builder SA.

Copy its backend/tfvars examples to ignored local files. Verify the proposed new
state key is unused and that none of the new names already has an owner. Supply
an actual administrator-verified OIDC ARN, or explicitly attest verified absence
before proposing provider creation. The default fails closed; SCP denial is not
proof of absence. Resolve the explicit deny in policy `p-uv1gtmxn` for
`iam:ListOpenIDConnectProviders` and scoped Get/Tag reads through the organization
administrator. No IAM grant can override an explicit SCP deny.

Local initialization/tests are safe; real plan review requires verified inputs:

```bash
terraform -chdir=deployments/existing-addons init -backend=false -input=false -lockfile=readonly
terraform -chdir=deployments/existing-addons test -no-color
```

After a separately reviewed phase authorizes backend use and actual inputs, an
operator can initialize with its backend.hcl and prepare a private saved plan.
**No apply is authorized here.** Initial preparation must propose only additive
resources, no old releases or database changes. gp3 is encrypted,
WaitForFirstConsumer and Retain; the 8Gi Jenkins claim does not wait for a consumer.
Creating it must not restart Jenkins or mount it into the existing controller.

After CSI/volume prerequisites are verified, quiet/backup/restore/cutover still
needs separate approval and consistent recovery proof. Change existing Jenkins
Helm values only through its existing lesson-8-9 owner; never declare the same
release in this additive state. The submitted Jenkins module supports the
existing claim/subpath. Likewise, apply the builder IRSA annotation only through
its existing SA owner, retaining Pod Identity until tested. Do not enable the
held root's duplicate IRSA/storage resources once this additive state owns them.
ESO-generated Secrets require explicit ownership review before replacing manual
ones. Secrets, SQL, GitOps publishing and application sync are separate live
changes. No existing state transfer is needed for this path.

## Clean demo command sequence

Run from `final-project/` in a reviewed checkout. The commands below are
instructions for a separately authorized deployment, not actions performed by
this remediation. Existing-infrastructure HOLD remains unchanged.

1. Prepare the supplied examples, then replace required placeholders with actual
   approved values. The backend bucket must be new; the two keys must differ.

   ```bash
   cp bootstrap/terraform.tfvars.example bootstrap/terraform.tfvars
   cp deployments/infra/backend.hcl.example deployments/infra/backend.hcl
   cp deployments/infra/terraform.tfvars.example deployments/infra/terraform.tfvars
   cp deployments/platform/backend.hcl.example deployments/platform/backend.hcl
   cp deployments/platform/terraform.tfvars.example deployments/platform/terraform.tfvars
   ```

   Match `state_bucket` to the new bucket and `infra_state_key` to the infra
   backend key. Keep live tfvars/backend files ignored. Obtain supported EKS,
   CSI/CNI and RDS inputs from AWS as described below. Do not substitute test
   fixtures, old lesson state or invented image digests.
2. Initialize and plan the new backend; inspect the saved plan privately.

   ```bash
   terraform -chdir=bootstrap init -input=false -lockfile=readonly
   terraform -chdir=bootstrap plan -input=false -out=bootstrap.tfplan
   ```

   Only after explicit bootstrap approval:

   ```bash
   terraform -chdir=bootstrap apply bootstrap.tfplan
   ```

   Retain/encrypt bootstrap's local state and verify the new bucket/key policy.
3. Initialize and plan infrastructure using that bucket. Apply only its reviewed
   saved plan after separate authorization.

   ```bash
   terraform -chdir=deployments/infra init -input=false -lockfile=readonly -backend-config=backend.hcl
   terraform -chdir=deployments/infra plan -input=false -out=infra.tfplan
   # Authorized execution only:
   terraform -chdir=deployments/infra apply infra.tfplan
   terraform -chdir=deployments/infra output -json platform
   ```

   Output is reference metadata, not secret values. No earlier homework state
   is consumed. Prove private-runner connectivity to the new endpoint before the
   platform stage; resolve organization IAM/OIDC restrictions before execution.
4. From the exact reviewed source, build/scan/publish the CI image to the **new**
   CI ECR repository under separately approved publishing scope. Populate the
   **new** GitOps secret through a secure channel. Fill the actual scanned image
   digest in platform tfvars; review the pinned builder advisories. See the CI
   tools/platform section for architecture, token scopes and ordering. Publish
   reviewed project source to branch `final-project` before Jenkins checks it out.
5. From the private runner, initialize and plan the platform; apply only after
   review and authorization. Sync/bootstrap/pruning remain false initially.

   ```bash
   terraform -chdir=deployments/platform init -input=false -lockfile=readonly -backend-config=backend.hcl
   terraform -chdir=deployments/platform plan -input=false -out=platform.tfplan
   # Authorized execution only:
   terraform -chdir=deployments/platform apply platform.tfplan
   ```

6. Verify ESO Ready, Jenkins's Bound claim, Argo/GitOps access and monitoring.
   Run Jenkins build-only, then approved GitOps publication with sync disabled.
   Review the actual rendered revision; separately authorize fresh-database
   bootstrap/migrations and application sync. Set `enable_application_sync=true`
   and, for the first approved fresh-role initialization only,
   `enable_database_bootstrap=true`, then create/review/apply a new platform plan.
   Turn bootstrap off after success. Keep pruning false. The application-ordering
   section defines the exact waves and DB precautions.
7. Capture the real successful Jenkins build, ECR digest, Argo revision, RDS/HTTP
   health, HPA metrics/scaling, custom dashboard and Jenkins replacement-survival
   evidence. A clean demonstration does not inherit historical lesson evidence.
   Cleanup or disruptive tests still require explicit scope; do not destroy the
   existing environment for a grade.

## Prerequisites and version discovery

Terraform >=1.14, AWS CLI v2 with approved credentials, Helm v3, kubectl within
one minor of the chosen cluster, Python 3.12, Docker for local image builds, and
Trivy are required. AWS profile reads were verified in `evidence/live-readiness.json`;
OIDC discovery is still SCP-denied. A working image builder and its actual output
remain required. An operator/runner must reach the private EKS endpoint from the
new VPC or an explicitly configured private network path; no public CIDR bypass
is supplied. Provision that runner under an approved organizational process.

Verify versions against AWS before filling infra tfvars. Use read-only
`aws eks describe-cluster-versions`, `aws eks describe-addon-versions` for
`aws-ebs-csi-driver` and `vpc-cni`, `aws rds describe-db-engine-versions` and
`aws rds describe-orderable-db-instance-options`. Confirm the selected region,
engine version, instance class, capacity/quota, CNI network-policy support and
EBS CSI compatibility. These deployment inputs are deliberately required;
offline test fixtures are not valid version discovery evidence.

Pinned chart versions/digests were retrieved from official indexes and saved in
`evidence/dependency-versions.json`. Jenkins plugins and required dependencies
are pinned against its chart core in `evidence/jenkins-plugin-pins.json`.
Image manifest digests and the official RDS CA hash are recorded separately.
Review pinned upstream releases for security changes and cluster compatibility
before deployment. Never silently choose repository latest.

## New backend bootstrap

Use `bootstrap/` only for a distinct new bucket/table. The existing backend is
still owned by lesson-5 and must not be recreated/imported. Review a bootstrap
plan using explicit bucket name, region and `new_environment=true`. The source
creates KMS encryption, versioned/private/TLS-only S3, a protected legacy lock
table with PITR, and local bootstrap state. Keep that local state encrypted and
backed up; do not lose it or bootstrap twice. The new project roots use native
S3 locking. Bootstrap and dependent roots are separate owners.

After separate approval and bootstrap execution, verify S3 versioning,
encryption, TLS denial, public access blocking, KMS policy, lockfile permissions
and table status. G01 requires actual authenticated init against that backend;
`init -backend=false` is only a local dependency check.

## Infrastructure stage

Initialize `deployments/infra` with reviewed backend bucket/region configuration
and a unique key for the environment. Fill all required, AWS-verified tfvars.
Prepare and review a complete saved plan. A separately approved execution
creates the VPC, private node group, private EKS endpoint, audit logs and KMS
secrets encryption, immutable encrypted ECR repositories, private encrypted RDS,
IRSA roles, EBS CSI, KMS-encrypted retained VPC flow logs, disabled public-IP
auto-assignment, and network-policy-enabled VPC CNI. The schema-aware named
SG map works even when cluster SG IDs are initially unknown.

RDS defaults here retain seven days of backups, deletion protection and a final
snapshot. The held root retains its historical settings for migration continuity;
security updates to existing RDS require a separate approved plan.

Outputs contain endpoint/ARN metadata only. Signing and application database
passwords use ephemeral generation and write-only secret values: they do not
enter Terraform state. GitHub tokens cannot be manufactured by Terraform:
create fine-grained, expiring credentials separately and populate the GitOps
Secrets Manager secret with JSON properties `push_token` and `read_token` using
an approved secret-management channel. The push token needs Contents write for
only the GitOps repository; the Argo token needs Contents read for that repo.
Do not pass token values in CLI arguments, Helm values, tfvars, logs or Git.
This secret write requires separate authorization. ESO receives only exact
secret ARNs and KMS decrypt through Secrets Manager. Never broaden to `*`.

## CI tools and platform stage

Build `ci/Dockerfile` with context `final-project/` on an approved local builder
for the worker architecture (default t3 nodes are amd64; use an amd64 builder
or an explicitly configured multi-platform build from an arm64 workstation),
scan it, push to the new CI-tools ECR repository and resolve its actual digest.
The Dockerfile pins its base and scanner images, verifies official Helm/kubectl
checksums, and installs hash-locked Python dependencies. Alpine security upgrades
and vendor-verified Git/Kerberos minimum versions are resolved during build; record the resulting SBOM and image digest. An image
build/push is not performed by source validation. Supply `ci_tools_image` as
`repository@sha256:...`, and the verified Kaniko digest from image-pins.json.
The archived builder is rejected for new rollout. Use the actually published
maintained replacement recorded in image-pins.json and review its two distinct
unscored advisories. It is not accepted solely because HIGH/CRITICAL counts are zero.

Initialize `deployments/platform` against its separate backend key; it reads
only the new infra state. Review its complete plan from the private runner.
Automatic sync, SQL bootstrap and pruning remain off during preparation.
After separate authorization, install the encrypted Retain gp3 StorageClass,
protected standalone Jenkins PVC, ESO, managed secret-store/ExternalSecrets,
Jenkins, Argo CD, metrics-server, monitoring, read-only verifier RBAC and the
Grafana dashboard. The PVC does not wait for binding until its first consumer.
The Kubernetes provider is not needed until infrastructure already exists.

ESO CRDs are installed in a prior Helm release. The CR resources are rendered
by a local Helm chart, avoiding Kubernetes manifest schema discovery before
CRD installation. Jenkins may wait until its token Secret reconciles; Argo
may initially report missing GitOps credentials or bootstrap image. Those are
failures/pending dependencies, not a successful rollout. Check ESO Ready and
read-only GitOps connectivity before triggering CI. A token refresh updates
Kubernetes Secrets; controller environment/JCasC credentials require a reviewed
Jenkins restart/reload to pick up changed environment values.

Jenkins sources the exact `final-project/Jenkinsfile` from branch `final-project`.
Use build-only default first, PUBLISH_GITOPS only for separately approved chart
publication while sync remains off, and DEPLOY only after rollout approval.
The pipeline checks out that SCM revision, runs application/chart/source tests,
scans dependencies, reuses or builds an immutable full-SHA image, scans that
published digest, aligns the chart without deleting extra GitOps features,
updates the digest and waits for the expected GitOps revision/image plus healthy
Argo rollout/database/schema. The verifier has only namespace-scoped read RBAC;
the builder has ECR access through IRSA and no Kubernetes API token. Initial replacement of existing GitOps templates requires an explicitly reviewed
full GitOps commit in `reviewed_gitops_base`. Subsequent canonical templates are
tracked by a hash manifest; external customizations, symlinks and extra files
block automation for review instead of being overwritten. Environment values
are preserved separately. Running
this pipeline writes ECR/GitOps and triggers Kubernetes/database mutations;
it needs explicit rollout authorization for the target environment.

## Application ordering and security

Argo applies configuration and ExternalSecrets at wave -3 and waits for
ExternalSecret Ready using its custom health check. A fresh environment's
opt-in database bootstrap Job at -2 creates the non-superuser app role from
separate app/admin secrets, granting database connection and schema ownership
capabilities needed for Django migrations. It does not grant RDS master access
to the web Deployment. SQL statement logging is disabled for this fresh database
to avoid logging password DDL. Execute bootstrap only after explicit database
mutation approval. Do not run it blindly against the existing database: existing
objects/owners need a reviewed grant/ownership migration and backup first.

A Sync hook at -1 runs schema migrations once per synchronization, then wave 0
rolls out the web pods. This is an Argo chart; the migration is not a Helm
pre-install hook that would precede its ConfigMap. Use Helm for lint/render,
Argo for delivery. Failed bootstrap/migration blocks rollout. Hooks retain
failure evidence and do not auto-delete before Argo can inspect their status.
Use backward-compatible expand/contract schema changes: rolling back an image
does not reverse a database migration. Database restore/reverse migration is a
separate approval and data-loss assessment.

Web/migration pods run non-root, drop capabilities, have read-only roots and
bounded writable tmp volumes, and do not receive Kubernetes API tokens. RDS
uses verify-full TLS with the official CA bundle; projected passwords are read
for every new connection so RDS secret rotation can recover without baking a
password into an image. Application-role password rotation must synchronize the
DB role with its Secrets Manager secret using an explicitly approved workflow;
only the RDS master secret has AWS-managed rotation by default.

Default application exposure is ClusterIP with explicit allowed hosts and
secure cookies. Local health checks send Host localhost. To publish externally,
review DNS, ingress controller, certificate issuer, HTTPS policy and trusted
proxy headers first, then set ingress TLS/host and Django proxy/CSRF/HSTS values.
Do not expose the admin over HTTP. HSTS/SSL redirect are optional until trusted
TLS termination exists; HTTPS ingress is required before public production use.
NetworkPolicy is enabled for the new environment; VPC CNI enforcement must be
verified. Existing feature flags remain opt-in under HOLD.

## Existing Jenkins storage cutover

Do not apply persistence values directly to the running ephemeral controller.
No migration is required when the old owners are retained. Obtain separate authorization
for the following downtime and storage operations:

1. Inventory current chart version, plugins, UID/GID, Jenkins home mount,
   PVC/PV/StorageClass, EBS CSI status, jobs/build queue and credential recovery
   material. Quiet Jenkins and stop new jobs; take an application-consistent
   private archive, checksum and off-cluster encrypted copy. Keep the existing
   running backup intact. Verify and rehearse using `scripts/jenkins-home.py`.
2. Provision CSI and the retained gp3 claim with a separate reviewed plan.
   WaitForFirstConsumer needs a consumer in the intended availability zone;
   ensure restore and controller placements are compatible with that EBS volume.
3. Adapt `platform/jenkins/restore-job.yaml` with the verified CI-tools image,
   private backup PVC, and a ConfigMap containing jenkins-home.py. Generate the
   review artifact using `scripts/render-jenkins-restore.py --image ...
   --backup-pvc ... --home-pvc ...`; it emits the ConfigMap and suspended Job. Its suspended
   state is intentional. Only after approval, stop the old controller, bind/mount
   the new PVC, then run the restore as UID/GID 1000. The tool requires nonempty recovery key/config files and restores into a new
   `restored/` subdirectory and refuses traversal, links, or an existing target.
4. Review the rendered Helm upgrade with `existing_claim` set to that claim and
   `existing_claim_sub_path=restored`. Preserve the deployed Jenkins chart/image
   and plugin versions for this cutover. Do not combine plugin upgrades with the
   initial storage move. Test recovery, jobs and credentials privately, then
   perform an approved pod replacement and verify same PV and preserved marker.
5. On failure keep jobs frozen, restore the previous configuration/backup with
   separately reviewed actions, retain the new PV and every backup, and do not
   destroy or overwrite the old recovery material. Never roll back to an empty
   home and claim persistence succeeded.

## Verification, troubleshooting and cost

Use `scripts/verify-final.sh` locally first. For read-only runtime collection,
pass `--runtime --context ... --cluster ... --region ... --rds-id ... --app-url ...`.
The wrapper returns nonzero while any gate lacks evidence; resource presence,
scan execution or HPA existence alone never proves all gates.

- ESO not Ready: inspect IAM exact secret ARNs, KMS grants, IRSA subject/audience,
  CRDs, token expiration and secret property names; never dump Secret data.
- Jenkins Pending: inspect PVC events, CSI compatibility, gp3 and AZ binding.
- Argo blocked: inspect repository access, exact GitOps revision, sync wave,
  migration status, image digest and required config; do not bypass hooks.
- Database readiness failure: verify SG reachability, private DNS, CA/hostname,
  password projection, role grants and schema. Liveness remains DB independent.
- HPA unknown: verify metrics-server and authenticated metrics API; scaling needs
  an approved load test plus before/after replicas, metrics, events and timestamps.
- Monitoring: require ready Prometheus/Grafana workloads, healthy scrape targets,
  dashboard discovery, actual numeric metrics and screenshots, not just pod lists.

Port-forward commands are in README. EKS, nodes, NAT, RDS, EBS and load balancers
incur ongoing regional charges. Single NAT and single-AZ RDS are disclosed lab
availability tradeoffs. No cloud bill or cleanup success is inferred from code.

## Controlled cleanup (separate authorization)

Choose the correct owner and prepare reviewed destroy plans; never execute them
under HOLD. For a disposable new environment: stop CI/Argo reconciliation;
review Application finalizers/pruning and app secrets; take verified DB/Jenkins
backups; then retire the platform while intentionally retaining its PVC/PV.
Explicitly review removal of PVC prevent_destroy and the Retain volume cleanup.
Remove add-ons/IRSA only after their consumers are retired. Review RDS deletion
protection disablement and a unique final snapshot name before infrastructure
teardown; disabling deletion protection is its own reviewed change. Retain KMS
keys long enough to recover snapshots, secrets, states and EBS volumes. Finish
all dependent states before any backend bootstrap retirement. S3/KMS/DynamoDB
protection must be intentionally reviewed, never bypassed with a force delete.
G17 requires a real controlled test on disposable infrastructure and evidence;
this procedure alone does not pass it.
