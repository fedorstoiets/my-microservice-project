#!/usr/bin/env bash
set -euo pipefail
REGION="${AWS_REGION:-us-east-2}"
CLUSTER=$(terraform output -raw cluster_name)
REPO=$(terraform output -raw ecr_repository_url)
aws eks update-kubeconfig --name "$CLUSTER" --region "$REGION"
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ --force-update
helm repo update
helm upgrade --install metrics-server metrics-server/metrics-server --namespace kube-system --wait --timeout 10m
kubectl create namespace neoversity --dry-run=client -o yaml | kubectl apply -f -
if ! kubectl -n neoversity get secret django-app-secrets >/dev/null 2>&1; then
  echo 'Create django-app-secrets with POSTGRES_PASSWORD and DJANGO_SECRET_KEY (see README).' >&2
  exit 1
fi
helm upgrade --install django-app charts/django-app --namespace neoversity  --set image.repository="$REPO" --wait --timeout 10m
kubectl -n neoversity rollout status deployment/django-app --timeout=180s
# Run migration from ONE Django pod; avoid concurrent migrations with multiple replicas.
kubectl -n neoversity exec deployment/django-app -- python manage.py migrate --noinput
kubectl -n neoversity get deploy,pods,svc,hpa,configmap
