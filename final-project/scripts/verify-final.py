#!/usr/bin/env python3
"""Collect bounded, read-only gate evidence. Missing evidence never counts as a pass."""
import argparse
import datetime
import json
import hashlib
import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[1]


def command(args, timeout=30):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout)
    if result.returncode:
        raise RuntimeError('Read-only check failed (details suppressed)')
    return result.stdout


def healthy_pods(data):
    pods = [pod for pod in data.get('items', []) if not pod.get('metadata', {}).get('deletionTimestamp') and pod.get('status', {}).get('phase') != 'Succeeded']
    return bool(pods) and all(pod.get('status', {}).get('phase') == 'Running' and any(c.get('type') == 'Ready' and c.get('status') == 'True' for c in pod.get('status', {}).get('conditions', [])) for pod in pods)


def persistent_jenkins_ready(pods, claims):
    bound = {item['metadata']['name'] for item in claims.get('items', []) if item.get('status', {}).get('phase') == 'Bound'}
    controllers = [pod for pod in pods.get('items', []) if pod.get('metadata', {}).get('labels', {}).get('app.kubernetes.io/component') == 'jenkins-controller']
    return bool(controllers) and healthy_pods({'items': controllers}) and all(
        any(volume.get('persistentVolumeClaim', {}).get('claimName') in bound for volume in pod.get('spec', {}).get('volumes', []))
        for pod in controllers
    )


def controller_ready(obj):
    replicas = obj.get('spec', {}).get('replicas', 1)
    status = obj.get('status', {})
    return replicas > 0 and status.get('observedGeneration', 0) >= obj.get('metadata', {}).get('generation', 1) and status.get('readyReplicas', 0) >= replicas


def monitoring_ready(pods, deployments, statefulsets):
    grafana = [obj for obj in deployments.get('items', []) if obj.get('metadata', {}).get('labels', {}).get('app.kubernetes.io/name') == 'grafana']
    prometheus = [obj for obj in statefulsets.get('items', []) if obj.get('metadata', {}).get('labels', {}).get('app.kubernetes.io/name') == 'prometheus']
    return healthy_pods(pods) and bool(grafana) and bool(prometheus) and all(controller_ready(obj) for obj in grafana + prometheus)


def documentation_review_valid():
    path = ROOT / 'docs/evidence/documentation-review.json'
    if not path.exists(): return False
    receipt = json.loads(path.read_text())
    required = {'README.md', 'docs/DEPLOYMENT.md', 'docs/MIGRATION-RUNBOOK.md', 'docs/EXECUTION-PLAN.md', 'docs/ACCEPTANCE-EVIDENCE.md'}
    files = receipt.get('files', {})
    return receipt.get('status') == 'passed' and required <= files.keys() and all(
        (ROOT / name).is_file() and hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest for name, digest in files.items()
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime', action='store_true')
    p.add_argument('--source-evidence', type=Path, help='Reuse a matching fingerprinted source validation receipt')
    for name in ['context', 'cluster', 'region', 'rds-id', 'app-url']:
        p.add_argument('--' + name)
    p.add_argument('--output', type=Path, default=ROOT / 'reports/gates.json')
    a = p.parse_args()
    if a.runtime and not all([a.context, a.cluster, a.region, a.rds_id, a.app_url]):
        p.error('Runtime checks require explicit context, cluster, region, rds-id and app-url')
    os.umask(0o077)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    gates = {f'G{i:02}': {'status': 'blocked', 'reason': 'Requires reviewed runtime evidence and separate authorization where applicable'} for i in range(1, 21)}
    if a.source_evidence:
        spec = importlib.util.spec_from_file_location('source_evidence', ROOT / 'scripts/source-evidence.py')
        source = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(source)
        receipt = json.loads(a.source_evidence.read_text())
        if receipt.get('code_sha256') == source.fingerprint() and receipt.get('results', {}).get('source', {}).get('status') == 'passed':
            gates['G02'] = {'status': 'passed', 'evidence': str(a.source_evidence)}
        else:
            gates['G02']['reason'] = 'Source evidence does not match current code or did not pass'
    else:
        try:
            log = command(['bash', str(ROOT / 'scripts/goaldevops-source-check.sh')], timeout=180)
            (a.output.parent / 'source-check.txt').write_text(log)
            gates['G02'] = {'status': 'passed', 'evidence': 'source-check.txt'}
        except (RuntimeError, subprocess.TimeoutExpired):
            gates['G02']['reason'] = 'Source validation failed or could not run; initialize local providers and test dependencies'
    if documentation_review_valid():
        gates['G18'] = {'status': 'passed', 'evidence': 'README.md, docs/DEPLOYMENT.md, docs/MIGRATION-RUNBOOK.md'}
    gates['G19']['reason'] = 'Clean-environment deployment explicitly blocked; source/mocked plans do not establish a deployment'
    security = ROOT / 'reports/security/summary.json'
    if security.exists():
        summary = json.loads(security.read_text())
        gates['G15']['reason'] = 'Source scan has unresolved findings or container image scan remains unverified'
        gates['G15']['source_scan'] = summary
    if a.runtime:
        try:
            cluster = json.loads(command(['aws', 'eks', 'describe-cluster', '--name', a.cluster, '--region', a.region, '--output', 'json']))['cluster']
            server = command(['kubectl', '--context', a.context, 'config', 'view', '--minify', '-o', 'jsonpath={.clusters[0].cluster.server}']).strip()
            if cluster['endpoint'] != server:
                raise RuntimeError('Kubernetes context does not match the explicit AWS cluster')
            def get(namespace, resource, name=None):
                return json.loads(command(['kubectl', '--context', a.context, '--request-timeout=10s', '-n', namespace, 'get', resource] + ([name] if name else []) + ['-o', 'json']))
            app = get('argocd', 'application', 'django-gitops')
            status = app.get('status', {})
            if healthy_pods(get('argocd', 'pods')) and status.get('sync', {}).get('status') == 'Synced' and status.get('health', {}).get('status') == 'Healthy':
                gates['G06'] = {'status': 'passed', 'evidence': 'Read-only live Application sync and health'}
            if monitoring_ready(get('monitoring', 'pods'), get('monitoring', 'deployments'), get('monitoring', 'statefulsets')):
                gates['G07'] = {'status': 'passed', 'evidence': 'Read-only monitoring pod readiness'}
            if persistent_jenkins_ready(get('jenkins', 'pods'), get('jenkins', 'pvc')):
                gates['G05'] = {'status': 'passed', 'evidence': 'Jenkins controller ready and mounts a Bound claim; replacement survival remains G14'}
            db = json.loads(command(['aws', 'rds', 'describe-db-instances', '--db-instance-identifier', a.rds_id, '--region', a.region, '--output', 'json']))['DBInstances'][0]
            config = get('neoversity', 'configmap', 'django-app-config')['data']
            eso = get('neoversity', 'externalsecret', 'django-rds-credentials')
            ready = any(c.get('type') == 'Ready' and c.get('status') == 'True' for c in eso.get('status', {}).get('conditions', []))
            request = urllib.request.Request(a.app_url.rstrip('/') + '/health/', headers={'Host': 'localhost'})
            with urllib.request.urlopen(request, timeout=10) as response:
                health = json.load(response)
            if ready and config['POSTGRES_HOST'] == db['Endpoint']['Address'] and config.get('POSTGRES_SSLMODE') == 'verify-full' and health.get('restricted_role') is True and not db['PubliclyAccessible'] and db['StorageEncrypted'] and health.get('connected') is True:
                gates['G11'] = {'status': 'passed', 'evidence': 'Live RDS identity/privacy/encryption, TLS config, non-master role, ESO Ready, and schema/database readiness'}
            for gate, url in [('G08', 'http://127.0.0.1:8080/login'), ('G10', 'http://127.0.0.1:3000/login')]:
                try:
                    with urllib.request.urlopen(url, timeout=5) as response:
                        if response.status == 200:
                            gates[gate] = {'status': 'passed' if gate == 'G08' else 'partial', 'evidence': 'Local UI reachable; dashboard live metrics still require evidence' if gate == 'G10' else 'Local Jenkins login reachable'}
                except OSError:
                    pass
        except (RuntimeError, OSError, ValueError, KeyError, subprocess.TimeoutExpired):
            gates['runtime_error'] = {'status': 'blocked', 'reason': 'Runtime check failed or credentials/context are unavailable; details suppressed'}
    result = {'source_commit': command(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']).strip(), 'checked_at': datetime.datetime.now(datetime.timezone.utc).isoformat(), 'runtime_requested': a.runtime, 'gates': gates}
    a.output.write_text(json.dumps(result, indent=2) + '\n')
    for gate, item in gates.items():
        print(gate + ': ' + item['status'])
    return 0 if all(item['status'] == 'passed' for item in gates.values()) else 2


if __name__ == '__main__':
    sys.exit(main())
