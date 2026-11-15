#!/usr/bin/env python3
"""Prepare a secret-free execution readiness packet. Never authorizes or performs writes."""
import argparse
import datetime
import hashlib
import importlib.util
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--inventory', type=Path, help='Fresh private version-pinned inventory summary')
    p.add_argument('--ownership', type=Path, help='Fresh private ownership.json from the same inventory')
    p.add_argument('--continuity-plan', type=Path, help='Private, complete Terraform JSON continuity plan')
    p.add_argument('--security-plan', type=Path, help='Private, complete separate security plan JSON')
    p.add_argument('--execution-source-manifest', type=Path, help='Private manifest of actual execution workspace including frozen deployed chart')
    p.add_argument('--output', type=Path, default=ROOT / 'docs/evidence/execution-readiness.json')
    args = p.parse_args()
    phases = [
        ('P00', 'Read-only identity, network, state/ID/provider inventory and permission preflight'),
        ('P01', 'Approved ownership-only state consolidation under freeze; preserve RDS/Helm'),
        ('P02', 'Approved in-place security hardening from a proven private runner'),
        ('P03', 'Approved OIDC/IRSA/EBS CSI preparation and retained Jenkins claim'),
        ('P04', 'Approved secret provisioning and read-only verification; capture actual ARNs'),
        ('P05', 'Approved Jenkins quiesce, consistent backup, restore and storage cutover'),
        ('P06', 'Approved CI image publishing, build-only pipeline and reviewed chart alignment'),
        ('P07', 'Separately approved existing DB ownership/grants/schema and application sync'),
        ('P08', 'Runtime acceptance, scaling/persistence tests and repeated drift checks'),
        ('P09', 'Separately approved clean-environment rehearsal/teardown and final publication'),
    ]
    packet = {'prepared_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'document': 'docs/EXECUTION-PLAN.md',
              'source_commit': subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip(),
              'source_branch': subprocess.check_output(['git', '-C', str(ROOT), 'branch', '--show-current'], text=True).strip(),
              'source_code_sha256': load('source-evidence').fingerprint(), 'migration_hold': 'active', 'execution_authorized': False,
              'status': 'blocked_missing_live_evidence', 'phases': [{'id': n, 'work': description, 'status': 'not_authorized'} for n, description in phases],
              'plan_reviews': {}, 'missing': []}
    if args.execution_source_manifest:
        packet['execution_source_manifest_sha256'] = hashlib.sha256(args.execution_source_manifest.read_bytes()).hexdigest()
    else:
        packet['missing'].append('Actual execution workspace manifest and frozen deployed chart evidence')
    expected = None
    if args.inventory and args.ownership:
        inventory = json.loads(args.inventory.read_text());rows = json.loads(args.ownership.read_text())
        if inventory.get('status') != 'inventory_complete' or inventory.get('duplicate_candidates') or any(not s.get('version_id') for s in inventory.get('states', [])) or any(r.get('deposed') for r in rows):
            packet['missing'].append('Inventory is incomplete, conflicted, deposed or unversioned')
        else:
            expected = {}
            for row in rows:
                owner = row['owner'].split('/')[0];address = row['address']
                include = owner in ['final-project', 'lesson-7', 'lesson-8-9'] or owner == 'lesson-5' and address.startswith('module.vpc.')
                if include:
                    if address in expected:packet['missing'].append('Duplicate destination address')
                    expected[address] = row['id']
            packet['inventory'] = {'sha256': hashlib.sha256(args.inventory.read_bytes()).hexdigest(), 'target_managed_count': len(expected),
                                   'ownership_sha256': hashlib.sha256(args.ownership.read_bytes()).hexdigest(), 'live_version_recheck_required': True}
    else:packet['missing'].append('Fresh complete inventory and ownership map')
    for key, path in [('continuity', args.continuity_plan), ('security', args.security_plan)]:
        if not path:
            packet['missing'].append(key + ' saved plan with full private JSON');continue
        plan = json.loads(path.read_text())
        if key == 'continuity':
            if expected is None:
                findings = ['Fresh ownership map required before continuity review']
            else:
                module = load('check-plan');findings = module.review(plan, len(expected))
                actual = {r['address']: r.get('values', {}).get('id') for r in module.managed_resources(plan.get('planned_values', {}).get('root_module', {}))}
                if actual != expected:findings.append('Plan physical IDs/addresses do not exactly match reviewed ownership map')
        else:
            findings = load('review-security-plan').review(plan)
            if expected is None:
                findings.append('Fresh physical ownership inventory required')
            else:
                resources = load('check-plan').managed_resources(plan.get('planned_values', {}).get('root_module', {}))
                actual = {r['address']: r.get('values', {}).get('id') for r in resources}
                if any(actual.get(address) != identity for address, identity in expected.items()):
                    findings.append('Security plan does not preserve every existing physical identity')
        packet['plan_reviews'][key] = {'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'within_scope': not findings, 'findings': findings}
        if findings:packet['missing'].append(key + ' plan review failed')
    packet['missing'] += ['Current AWS/private-runner access and SCP/permissions evidence', 'Verified consistent backup and restored claim',
                           'Actual built/scanned application and CI tools digests; unscored builder advisory disposition',
                           'Independent operator signoff and explicit phase-specific authorization']
    args.output.parent.mkdir(parents=True, exist_ok=True);args.output.write_text(json.dumps(packet, indent=2) + '\n')
    print('Execution packet: BLOCKED; HOLD active; no actions executed')
    return 2


if __name__ == '__main__':raise SystemExit(main())
