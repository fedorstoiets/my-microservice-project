#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# ConfigMap in jenkins namespace for kaniko ECR helper
kubectl -n jenkins create configmap kaniko-docker-config   --from-literal=config.json='{"credsStore":"ecr-login"}'   --dry-run=client -o yaml | kubectl apply -f -
# Legacy Helm release must not compete with Argo CD for same resources.
if helm -n neoversity status django-app >/dev/null 2>&1; then
  echo 'Existing lesson-7 Helm release django-app detected.'
  echo 'Run: helm uninstall django-app -n neoversity'
  echo 'This deletes the ephemeral PostgreSQL deployment and resets its data.'
  echo 'Then: kubectl -n argocd annotate application django-gitops argocd.argoproj.io/refresh=hard --overwrite'
fi
kubectl -n jenkins get pods
kubectl -n argocd get pods
kubectl -n argocd get applications.argoproj.io
printf '
Jenkins (in separate terminal): kubectl -n jenkins port-forward svc/jenkins 8080:8080
'
printf 'Argo CD (in separate terminal): kubectl -n argocd port-forward svc/argocd-server 8081:443
'
