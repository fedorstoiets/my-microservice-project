#!/usr/bin/env bash
# TOP 3 — IaC security scan; optional strict mode for CI.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPORT_DIR:-$ROOT/reports}"
mkdir -p "$OUT"
if ! command -v trivy >/dev/null; then
  echo "ERROR: Trivy is not installed. See docs/TOP-1-4.md." >&2
  exit 2
fi
# Reports and non-blocking security review are separate from strict CI enforcement.
echo "Scanning Terraform and Kubernetes manifests in $ROOT"
trivy config --quiet --format json --output "$OUT/trivy-config.json" "$ROOT"
trivy config --severity HIGH,CRITICAL --exit-code 0 --format table "$ROOT" | tee "$OUT/trivy-summary.txt"
if [[ "${STRICT_SECURITY:-false}" == "true" ]]; then
  echo "Strict mode: HIGH/CRITICAL findings will fail the scan."
  trivy config --quiet --severity HIGH,CRITICAL --exit-code 1 "$ROOT"
fi
echo "Reports: $OUT (review findings; non-strict mode is not a security pass)."
