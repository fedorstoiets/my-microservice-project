# Neoversity Django GitOps repository
Public repository `fedorstoiets/neoversity-django-gitops`, branch `main`.
Jenkins updates `charts/django-app/values.yaml` under `image.tag` and pushes to `main`; Argo CD reconciles it into `neoversity`.
Kubernetes Secret `django-app-secrets` must already exist. This chart is a temporary lab: PostgreSQL `emptyDir` loses data on pod replacement.
