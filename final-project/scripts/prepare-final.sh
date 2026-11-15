#!/usr/bin/env bash
set -Eeuo pipefail
# Fail closed before initialization, planning, or any backend access.
cat >&2 <<'HOLD'
MIGRATION HOLD: this legacy planning helper is disabled.
The root declares resources still owned by other states; disabling database or
monitoring can remove existing resources. Do not use old saved plans.
Run bash scripts/goaldevops-source-check.sh for local source validation.
See docs/MIGRATION-HOLD.md for migration review prerequisites.
HOLD
exit 1
