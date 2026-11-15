#!/usr/bin/env bash
# Default is local-only. Runtime collection requires explicit cluster/context inputs.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${PYTHON:-python3}" "$ROOT/scripts/verify-final.py" "$@"
