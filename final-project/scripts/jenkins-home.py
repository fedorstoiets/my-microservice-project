#!/usr/bin/env python3
"""Validate or restore a private Jenkins backup locally; never contacts Jenkins/Kubernetes."""
import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import tarfile


def validate(archive):
    names = set()
    by_name = {}
    members = []
    for member in archive.getmembers():
        path = PurePosixPath(member.name)
        if path.is_absolute() or ".." in path.parts or member.issym() or member.islnk() or member.isdev() or member.isfifo():
            raise ValueError("Unsafe backup entry; archive must be reviewed privately")
        normalized = str(path)
        names.add(normalized)
        by_name[normalized] = member
        members.append(member)
    # Accept archives rooted at '.' or 'var/jenkins_home', without guessing a restore prefix.
    prefixes = {n[:-len("config.xml")] for n in names if n.endswith("config.xml")}
    required = ["config.xml", "secrets/master.key", "secrets/hudson.util.Secret"]
    roots = [prefix for prefix in prefixes if all(prefix + item in names and by_name[prefix + item].isfile() and by_name[prefix + item].size > 0 for item in required)]
    if len(roots) != 1:
        raise ValueError("Backup lacks one unambiguous Jenkins home with required credential decryption material")
    return roots[0], members


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("archive", type=Path)
    p.add_argument("--restore-to", type=Path, help="New, empty local directory only; not a live Jenkins home")
    a = p.parse_args()
    os.umask(0o077)
    with tarfile.open(a.archive, "r:*") as archive:
        prefix, members = validate(archive)
        if a.restore_to:
            a.restore_to.mkdir(mode=0o700, exist_ok=False, parents=True)
            for member in members:
                normalized = str(PurePosixPath(member.name))
                if not normalized.startswith(prefix):
                    continue
                relative = normalized[len(prefix):]
                if not relative or relative == ".":
                    continue
                target = a.restore_to / relative
                if member.isdir():
                    target.mkdir(parents=True, exist_ok=True, mode=0o700)
                elif member.isfile():
                    target.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
                    with archive.extractfile(member) as source, target.open("xb") as output:
                        while block := source.read(1024 * 1024):
                            output.write(block)
                    target.chmod(0o600)
    digest = hashlib.file_digest(a.archive.open("rb"), "sha256").hexdigest()
    print("PASS: required Jenkins files and safe archive paths; SHA256=" + digest)
    print("Application-consistent backup and recovery verification are still required before storage migration.")


if __name__ == "__main__":
    main()
