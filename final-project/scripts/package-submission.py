#!/usr/bin/env python3
"""Build a deterministic, allowlisted draft archive; final mode fails closed on open gates."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_DIRS = {'Django', 'bootstrap', 'charts', 'ci', 'deployments', 'docs', 'modules', 'monitoring', 'platform', 'scripts', 'tests'}
ALLOWED_SUFFIXES = {'.tf', '.hcl', '.md', '.yaml', '.yml', '.json', '.py', '.sh', '.txt', '.in', '.tpl', '.html', '.pem', '.conf', '.jsonpatch', '.sha256'}


def allowed(path):
    if path.is_symlink() or not path.is_file():
        return False
    relative = path.relative_to(ROOT)
    if any(part in {'.git', '.terraform', '__pycache__', '.venv', 'reports', 'dist', 'staticfiles'} for part in relative.parts):
        return False
    if relative.parts[0] not in ALLOWED_DIRS and len(relative.parts) > 1:
        return False
    name = path.name
    if name in {'backend.hcl', '.env', 'crash.log'} or (name.startswith('.env') and name != '.env.example') or '.PRIVATE' in name:
        return False
    if any(token in name for token in ['.tfstate', '.tfplan', 'backup.tar', 'credential', '.key']):
        return False
    if '.tfvars' in name and not name.endswith('.tfvars.example'):
        return False
    if path.suffix == '.pem':
        return relative == Path('Django/certs/rds-global-bundle.pem')
    return name in {'.gitignore', '.dockerignore', '.env.example', '.terraform.lock.hcl', 'Jenkinsfile', 'Dockerfile', 'backend.hcl.example', 'terraform.tfvars.example'} or path.suffix in ALLOWED_SUFFIXES


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--final', action='store_true')
    p.add_argument('--gates', type=Path, default=ROOT / 'reports/gates.json')
    p.add_argument('--output-dir', type=Path, default=ROOT / 'dist')
    a = p.parse_args()
    branch = subprocess.check_output(['git', '-C', str(ROOT), 'branch', '--show-current'], text=True).strip()
    commit = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    dirty = bool(subprocess.check_output(['git', '-C', str(ROOT), 'status', '--porcelain', '--', '.'], text=True).strip())
    if a.final:
        if branch != 'final-project' or dirty:
            raise SystemExit('Final packaging requires a clean, reviewed final-project branch')
        evidence = json.loads(a.gates.read_text())
        if evidence.get('source_commit') != commit:
            raise SystemExit('Gate evidence must identify this exact reviewed source commit')
        gates = evidence['gates']
        if any(gates.get(f'G{i:02}', {}).get('status') != 'passed' for i in range(1, 21)):
            raise SystemExit('Final packaging requires evidence for all G01–G20 gates')
    files = sorted((p for p in ROOT.rglob('*') if allowed(p)), key=lambda p: str(p.relative_to(ROOT)))
    contents = {path: path.read_bytes() for path in files}
    for path, raw in contents.items():
        if re.search(rb'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|(?:AKIA|ASIA)[A-Z0-9]{16}|gh[pousr]_[A-Za-z0-9]{30,}', raw):
            raise SystemExit('Potential credential material detected; review privately: ' + str(path.relative_to(ROOT)))
        if path.suffix == '.json':
            try:
                document = json.loads(raw)
                if isinstance(document, dict) and (('lineage' in document and 'resources' in document) or 'planned_values' in document or {'AccessKeyId', 'SecretAccessKey'} <= document.keys()):
                    raise SystemExit('Raw state/plan/credential JSON is excluded: ' + str(path.relative_to(ROOT)))
            except (ValueError, UnicodeDecodeError):
                pass
    manifest = {'draft': not a.final, 'branch': branch, 'commit': commit, 'dirty': dirty, 'files': {str(p.relative_to(ROOT)): hashlib.sha256(raw).hexdigest() for p, raw in contents.items()}}
    a.output_dir.mkdir(parents=True, exist_ok=True)
    filename = 'final_DevOps_Стоєцький_Федір' + ('' if a.final else '.draft') + '.zip'
    target = a.output_dir / filename
    with zipfile.ZipFile(target, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            info = zipfile.ZipInfo('final-project/' + str(path.relative_to(ROOT)), date_time=(2000, 1, 1, 0, 0, 0))
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, contents[path])
        info = zipfile.ZipInfo('MANIFEST.json', date_time=(2000, 1, 1, 0, 0, 0))
        archive.writestr(info, json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    digest = hashlib.file_digest(target.open('rb'), 'sha256').hexdigest()
    (target.with_suffix('.zip.sha256')).write_text(digest + '  ' + target.name + '\n')
    print(('FINAL' if a.final else 'DRAFT') + ': ' + str(target))
    print('SHA256: ' + digest + '; source files: ' + str(len(files)))


if __name__ == '__main__':
    main()
