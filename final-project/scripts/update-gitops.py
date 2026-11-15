#!/usr/bin/env python3
"""Update only the submitted chart and immutable image in a prepared GitOps checkout."""
import argparse
from pathlib import Path
import re
import shutil
import hashlib
import json
import subprocess
import yaml


def merge(base, override):
    result = dict(base)
    for key, value in override.items():
        result[key] = merge(result[key], value) if isinstance(value, dict) and isinstance(result.get(key), dict) else value
    return result



def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("checkout", type=Path)
    p.add_argument("--image", required=True)
    p.add_argument("--tag", required=True)
    p.add_argument("--reviewed-base", default="", help="Explicitly reviewed initial GitOps commit; no branch-tip guessing")
    a = p.parse_args()
    if not re.fullmatch(r"[^\s]+@sha256:[a-f0-9]{64}", a.image):
        p.error("image must be a repository@sha256 digest")
    if not re.fullmatch(r"[a-f0-9]{40}", a.tag):
        p.error("tag must be the complete source commit")
    root = Path(__file__).resolve().parents[1]
    source = root / "charts/django-app"
    target = a.checkout / "charts/django-app"
    for base in [source, target]:
        if base.exists() and any(path.is_symlink() for path in base.rglob("*")):
            raise SystemExit("Symlinks require review before chart alignment")
    # Never discard additional GitOps features: fail for review on extra files.
    marker = target / ".goaldevops-source.json"
    source_hashes = {str(p.relative_to(source)): hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob("*") if p.is_file() and p.name != "values.yaml"}
    if target.exists():
        extra = {str(p.relative_to(target)) for p in target.rglob("*") if p.is_file() and p.name != ".goaldevops-source.json"} - {str(p.relative_to(source)) for p in source.rglob("*") if p.is_file()}
        if extra:
            raise SystemExit("GitOps contains extra chart files; reconcile before automation: " + ", ".join(sorted(extra)))
    differences = [name for name, digest in source_hashes.items() if (target / name).exists() and hashlib.sha256((target / name).read_bytes()).hexdigest() != digest]
    if marker.exists():
        previous = json.loads(marker.read_text())["files"]
        customized = [name for name, digest in previous.items() if not (target / name).is_file() or hashlib.sha256((target / name).read_bytes()).hexdigest() != digest]
        if customized:
            raise SystemExit("GitOps chart was customized after alignment; review before overwrite: " + ", ".join(customized))
    elif differences:
        if not a.reviewed_base:
            raise SystemExit("Initial chart alignment requires the explicitly reviewed GitOps HEAD")
        revision = subprocess.check_output(["git", "-C", str(a.checkout), "rev-parse", "HEAD"], text=True).strip()
        if not a.reviewed_base or a.reviewed_base != revision:
            raise SystemExit("Initial chart alignment changes existing templates; require the explicitly reviewed GitOps HEAD")
    existing = yaml.safe_load((target / "values.yaml").read_text()) if (target / "values.yaml").exists() else {}
    merged = merge(yaml.safe_load((source / "values.yaml").read_text()), existing or {})
    if merged.get("postgresql", {}).get("enabled"):
        raise SystemExit("GitOps still enables in-cluster PostgreSQL; reconcile ownership before chart alignment")
    if merged.get("config", {}).get("DJANGO_ALLOWED_HOSTS") == "*":
        raise SystemExit("Replace wildcard allowed hosts in reviewed GitOps environment values before alignment")
    shutil.copytree(source, target, dirs_exist_ok=True)
    repository, digest = a.image.rsplit("@", 1)
    merged["image"].update(repository=repository, digest=digest, tag=a.tag)
    (target / "values.yaml").write_text(yaml.safe_dump(merged, sort_keys=False))
    marker.write_text(json.dumps({"source_commit": a.tag, "files": source_hashes}, indent=2) + "\n")
    # Environment values remain in the Argo Application's valuesObject.
    subprocess.run(["git", "-C", str(a.checkout), "add", "charts/django-app"], check=True)


if __name__ == "__main__":
    main()
