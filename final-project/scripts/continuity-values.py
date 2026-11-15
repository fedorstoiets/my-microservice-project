#!/usr/bin/env python3
"""Extract deployed Helm values from private backups for a continuity-only plan."""
import argparse
import json
import os
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('state_files', type=Path, nargs='+')
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
os.umask(0o077)
keys = {'jenkins': 'jenkins', 'argocd': 'argocd', 'neoversity-apps': 'applications', 'monitoring': 'monitoring'}
result = {"security_profile": "continuity", "private_runner_verified": False}
for path in a.state_files:
    for resource in json.loads(path.read_text()).get('resources', []):
        if resource.get('mode') != 'managed' or resource.get('type') != 'helm_release':
            continue
        for instance in resource.get('instances', []):
            attrs = instance.get('attributes', {})
            name = attrs.get('name')
            if name in keys:
                key = 'continuity_' + keys[name] + '_values'
                if key in result:
                    raise SystemExit('Duplicate Helm ownership; investigate before continuity planning')
                if any(attrs.get(field) for field in ['set', 'set_list', 'set_sensitive', 'set_wo']):
                    raise SystemExit('Helm set overrides found; extend and review continuity inputs before proceeding')
                result[key] = attrs.get('values') or []
if len(result) != len(keys) + 2:
    raise SystemExit('Not all four deployed Helm releases were found')
with a.output.open('x') as output:
    json.dump(result, output, indent=2)
    output.write('\n')
print('Private continuity inputs written; no state or resource modified')
