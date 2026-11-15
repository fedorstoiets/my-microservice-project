#!/usr/bin/env python3
"""Run local source/security checks and record sanitized, fingerprinted evidence."""
import datetime
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import shutil

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('source_evidence', root / 'scripts/source-evidence.py')
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
os.umask(0o077)
reports = root / 'reports'
reports.mkdir(exist_ok=True)
archive = reports / 'validation-history' / datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
archive.mkdir(parents=True, exist_ok=False)
for filename in ['source-check.txt', 'security-check.txt']:
    previous = reports / filename
    if previous.exists():
        shutil.copy2(previous, archive / filename)
        (archive / filename).chmod(0o600)
before = source.fingerprint()
results = {}
started = time.time()
for name, command in [('source', ['bash', 'scripts/goaldevops-source-check.sh']), ('security', ['bash', 'scripts/security-scan.sh'])]:
    environment = dict(os.environ, PYTHON=sys.executable, STRICT_SECURITY='true')
    with (reports / (name + '-check.txt')).open('w') as log:
        result = subprocess.run(command, cwd=root, env=environment, stdout=log, stderr=subprocess.STDOUT)
    results[name] = {'exit_code': result.returncode, 'status': 'passed' if result.returncode == 0 else 'failed', 'report': 'reports/' + name + '-check.txt'}
    print(name + ': ' + results[name]['status'])
after = source.fingerprint()
if before != after:
    raise SystemExit('Source changed during validation; repeat after review')
receipt = {'checked_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'code_sha256': after, 'results': results, 'infrastructure_mutated': False, 'terraform_tests': 'AWS/Kubernetes/Helm mocked; plan only', 'live_database_used': False}
(root / 'docs/evidence/local-validation.json').write_text(json.dumps(receipt, indent=2) + '\n')
summary = root / 'reports/security/summary.json'
if summary.exists() and summary.stat().st_mtime >= started:
    (root / 'docs/evidence/security-summary.json').write_bytes(summary.read_bytes())
sys.exit(0 if all(r['status'] == 'passed' for r in results.values()) else 1)
