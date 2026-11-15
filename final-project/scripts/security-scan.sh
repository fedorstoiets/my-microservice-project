#!/usr/bin/env bash
# Store raw reports privately; print counts/identifiers only, never source snippets.
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPORT_DIR:-$ROOT/reports/security}"
mkdir -p "$OUT"
command -v trivy >/dev/null
trivy config --quiet --skip-dirs '**/.terraform' --skip-dirs reports --skip-dirs dist --format json --output "$OUT/config.json" "$ROOT"
trivy fs --quiet --scanners vuln,secret --skip-dirs .terraform --skip-dirs reports --skip-dirs dist --format json --output "$OUT/application.json" "$ROOT/Django"
trivy fs --quiet --scanners vuln,secret --format json --output "$OUT/ci.json" "$ROOT/ci"
mkdir -p "$OUT/rendered"
helm template django-app "$ROOT/charts/django-app" --namespace neoversity \
  --set config.POSTGRES_HOST=example.invalid --set externalSecrets.enabled=true \
  --set externalSecrets.rdsSecretArn=offline-app --set externalSecrets.djangoSecretArn=offline-signing \
  --set databaseBootstrap.enabled=true --set databaseBootstrap.adminSecretArn=offline-admin \
  --set networkPolicy.enabled=true --set 'networkPolicy.databaseCidrs[0]=10.80.4.0/24' > "$OUT/rendered/app.yaml"
trivy config --quiet --format json --output "$OUT/rendered.json" "$OUT/rendered"
"${PYTHON:-python3}" - "$OUT" "${STRICT_SECURITY:-true}" <<'PY'
import collections,json,sys,datetime
from pathlib import Path
root=Path(sys.argv[1]);counts=collections.Counter();ids=collections.Counter()
for name in ['config','application','ci','rendered']:
 data=json.loads((root/(name+'.json')).read_text())
 for result in data.get('Results',[]):
  for kind in ['Misconfigurations','Vulnerabilities','Secrets']:
   for finding in result.get(kind,[]) or []:
    if kind=='Misconfigurations' and finding.get('Status') not in [None,'FAIL']: continue
    severity=finding.get('Severity','UNKNOWN');counts[severity]+=1
    ids[finding.get('AVDID') or finding.get('ID') or finding.get('VulnerabilityID') or finding.get('RuleID','UNKNOWN')]+=1
summary={'checked_at':datetime.datetime.now(datetime.timezone.utc).isoformat(),'counts':dict(counts),'finding_ids':dict(ids),'strict':sys.argv[2]=='true','passed':not(counts['HIGH'] or counts['CRITICAL'])}
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
if summary['strict'] and not summary['passed']:sys.exit(1)
PY
