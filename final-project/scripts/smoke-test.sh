#!/usr/bin/env bash
# TOP 1 — Application smoke test. Validates HTTP + PostgreSQL SELECT 1.
set -Eeuo pipefail
NAMESPACE="${NAMESPACE:-neoversity}"
SERVICE="${SERVICE:-django-app}"
BASE_URL="${BASE_URL:-}"
TIMEOUT="${TIMEOUT:-20}"
if [[ -z "$BASE_URL" ]]; then
  host="$(kubectl -n "$NAMESPACE" get svc "$SERVICE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
  if [[ -z "$host" ]]; then
    echo "ERROR: No external LoadBalancer hostname; set BASE_URL=http://host:port or create port-forward." >&2
    exit 2
  fi
  BASE_URL="http://$host"
fi
BASE_URL="${BASE_URL%/}"
echo "Checking $BASE_URL/health/"
health="$(curl -fsS --retry 4 --retry-delay 3 --connect-timeout 8 --max-time "$TIMEOUT" "$BASE_URL/health/")"
python3 -c 'import json,sys; data=json.loads(sys.argv[1]); assert data.get("status")=="ok" and data.get("connected") is True, f"Unhealthy response: {data}"; print("PASS: Django health endpoint and PostgreSQL SELECT 1")' "$health"
echo "Checking $BASE_URL/"
curl -fsS --retry 4 --retry-delay 3 --connect-timeout 8 --max-time "$TIMEOUT" -o /dev/null "$BASE_URL/"
echo "PASS: Django homepage HTTP 2xx; smoke test completed"
