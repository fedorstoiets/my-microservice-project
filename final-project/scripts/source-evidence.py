"""Code fingerprint excluding credentials, generated output and documentation receipts."""
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def fingerprint():
    digest = hashlib.sha256()
    for path in sorted(ROOT.rglob('*')):
        if not path.is_file() or path.is_symlink():
            continue
        relative = path.relative_to(ROOT)
        if relative.parts[0] == 'docs' or any(part in {'.git', '.terraform', '__pycache__', '.venv', 'reports', 'dist', 'staticfiles'} for part in relative.parts):
            continue
        if path.name in {'backend.hcl', 'crash.log'} or '.tfstate' in path.name or '.tfplan' in path.name or '.tfvars' in path.name and not path.name.endswith('.tfvars.example') or path.name.startswith('.env'):
            continue
        if path.suffix not in {'.tf', '.hcl', '.yaml', '.yml', '.py', '.sh', '.txt', '.in', '.tpl', '.conf', '.pem', '.html', '.json', '.example'} and path.name not in {'Jenkinsfile', 'Dockerfile', '.dockerignore', '.gitignore'}:
            continue
        digest.update(str(relative).encode() + b'\0' + hashlib.sha256(path.read_bytes()).digest())
    return digest.hexdigest()
