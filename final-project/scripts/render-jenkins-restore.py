#!/usr/bin/env python3
"""Render a suspended restore Job and its script ConfigMap; never submits them."""
import argparse
from pathlib import Path
import re
import yaml

root = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--image', required=True)
p.add_argument('--backup-pvc', required=True)
p.add_argument('--home-pvc', default='jenkins-home')
a = p.parse_args()
if not re.fullmatch(r'[^\s]+@sha256:[a-f0-9]{64}', a.image):
    p.error('Supply the actual verified CI-tools image digest')
for name in [a.backup_pvc, a.home_pvc]:
    if not re.fullmatch(r'[a-z0-9]([a-z0-9.-]*[a-z0-9])?', name):
        p.error('Invalid PVC name')
job = yaml.safe_load((root / 'platform/jenkins/restore-job.yaml').read_text())
spec = job['spec']['template']['spec']
spec['containers'][0]['image'] = a.image
for volume in spec['volumes']:
    if volume['name'] == 'home': volume['persistentVolumeClaim']['claimName'] = a.home_pvc
    if volume['name'] == 'backup': volume['persistentVolumeClaim']['claimName'] = a.backup_pvc
config = {'apiVersion': 'v1', 'kind': 'ConfigMap', 'metadata': {'name': 'jenkins-restore-script', 'namespace': 'jenkins'}, 'data': {'jenkins-home.py': (root / 'scripts/jenkins-home.py').read_text()}}
print(yaml.safe_dump_all([config, job], sort_keys=False))
