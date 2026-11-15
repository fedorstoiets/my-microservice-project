#!/usr/bin/env python3
"""Local source regressions; no infrastructure, backend or database access."""
import ast
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
for folder in ['Django', 'scripts', 'tests', 'ci']:
    for path in (root / folder).rglob('*.py'):
        ast.parse(path.read_text(), filename=str(path))
for path in (root / 'scripts').glob('*.sh'):
    subprocess.run(['bash', '-n', str(path)], check=True)
if (root / 'Jenkinsfile').read_bytes() != (root / 'Django/Jenkinsfile').read_bytes():
    raise SystemExit('Pipeline copies differ')
subprocess.run([sys.executable, '-m', 'unittest', 'discover', '-s', str(root / 'tests'), '-v'], check=True)
