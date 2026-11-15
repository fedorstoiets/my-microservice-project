#!/usr/bin/env python3
"""Read-only, version-pinned S3 state inventory. Raw backups stay private."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys


def aws(*args):
    r = subprocess.run(["aws", *args, "--cli-connect-timeout", "10", "--cli-read-timeout", "20", "--output", "json"], capture_output=True, text=True, timeout=60)
    if r.returncode:
        raise RuntimeError("AWS read failed; check authentication, region and read permissions (details suppressed)")
    return json.loads(r.stdout or "{}")


def entries(state, owner):
    for resource in state.get("resources", []):
        if resource.get("mode") != "managed":
            continue
        base = ((resource.get("module") + ".") if resource.get("module") else "") + resource["type"] + "." + resource["name"]
        for instance in resource.get("instances", []):
            key = instance.get("index_key")
            address = base + ("[" + json.dumps(key) + "]" if key is not None else "")
            attributes = instance.get("attributes", {})
            identity = attributes.get("id") or attributes.get("arn")
            yield {"owner": owner, "address": address, "type": resource["type"], "id": identity, "provider": resource.get("provider"), "deposed": instance.get("deposed")}


def duplicates(rows):
    grouped = {}
    for row in rows:
        if row["id"]:
            grouped.setdefault((row["type"], str(row["id"])), []).append(row)
    return [owners for owners in grouped.values() if len(owners) > 1]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bucket", required=True)
    p.add_argument("--region", required=True)
    p.add_argument("--output", type=Path, required=True, help="New private backup directory outside Git")
    p.add_argument("--discover", action="store_true", help="Include all discovered .tfstate keys; candidates still require an owner review")
    p.add_argument("--keys", nargs="+", default=["lesson-5/terraform.tfstate", "lesson-7/terraform.tfstate", "lesson-8-9/terraform.tfstate", "final-project/terraform.tfstate"])
    a = p.parse_args()
    repository = Path(subprocess.check_output(["git", "rev-parse", "--show-toplevel"], text=True)).resolve()
    if a.output.resolve() == repository or repository in a.output.resolve().parents:
        p.error("Raw state backups must be outside the Git repository")
    os.umask(0o077)
    a.output.mkdir(mode=0o700, parents=True, exist_ok=False)
    result = {"checked_at": datetime.datetime.now(datetime.timezone.utc).isoformat(), "status": "blocked", "states": [], "duplicate_candidates": []}
    rows = []
    try:
        aws("sts", "get-caller-identity")
        if a.discover:
            listing = aws("s3api", "list-objects-v2", "--bucket", a.bucket, "--region", a.region)
            discovered = {item["Key"] for item in listing.get("Contents", []) if item["Key"].endswith(".tfstate")}
            a.keys = sorted(set(a.keys) | discovered)
        result["keys_checked"] = a.keys
        result["discovery_requested"] = a.discover
        result["duplicate_scope"] = "Requested/discovered state objects; owner review must distinguish active states and archived copies"
        versioning = aws("s3api", "get-bucket-versioning", "--bucket", a.bucket, "--region", a.region)
        if versioning.get("Status") != "Enabled":
            raise RuntimeError("State bucket versioning is not enabled")
        for n, key in enumerate(a.keys):
            head = aws("s3api", "head-object", "--bucket", a.bucket, "--key", key, "--region", a.region)
            version = head.get("VersionId")
            if not version or version == "null":
                raise RuntimeError("State object has no immutable version ID")
            raw_path = a.output / f"state-{n}.json"
            aws("s3api", "get-object", "--bucket", a.bucket, "--key", key, "--version-id", version, "--region", a.region, str(raw_path))
            raw = raw_path.read_bytes()
            state = json.loads(raw)
            current = aws("s3api", "head-object", "--bucket", a.bucket, "--key", key, "--region", a.region)
            if current.get("VersionId") != version:
                raise RuntimeError("State changed during inventory; freeze and repeat")
            rows.extend(entries(state, key))
            result["states"].append({"key": key, "version_id": version, "serial": state.get("serial"), "lineage": state.get("lineage"), "sha256": hashlib.sha256(raw).hexdigest()})
        result["duplicate_candidates"] = duplicates(rows)
        result["status"] = "review_required" if result["duplicate_candidates"] else "inventory_complete"
        (a.output / "ownership.json").write_text(json.dumps(rows, indent=2) + "\n")
    except (RuntimeError, OSError, ValueError, subprocess.TimeoutExpired) as error:
        result["error"] = str(error) if isinstance(error, RuntimeError) else "Inventory failed; private backups retained"
    (a.output / "summary.json").write_text(json.dumps(result, indent=2) + "\n")
    print("State inventory:", result["status"], "(private report written; no state modified)")
    return 0 if result["status"] == "inventory_complete" else 1


if __name__ == "__main__":
    sys.exit(main())
