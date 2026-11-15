#!/usr/bin/env python3
"""Read-only: require the expected GitOps revision, digest, readiness, and HTTP/DB health."""
import argparse
import json
import subprocess
import time
import urllib.request
import sys


def get(namespace, resource, name):
    return json.loads(subprocess.check_output(["kubectl", "--request-timeout=10s", "-n", namespace, "get", resource, name, "-o", "json"], stderr=subprocess.DEVNULL))


def delivery_ready(app, deploy, revision, image):
    spec, status = deploy['spec'], deploy.get('status', {})
    replicas = spec.get('replicas', 1)
    return (
        replicas > 0 and status.get('observedGeneration', 0) >= deploy['metadata']['generation']
        and all(status.get(key, 0) == replicas for key in ['replicas', 'updatedReplicas', 'availableReplicas', 'readyReplicas'])
        and spec['template']['spec']['containers'][0]['image'] == image
        and app.get('sync', {}).get('revision') == revision and app.get('sync', {}).get('status') == 'Synced'
        and app.get('health', {}).get('status') == 'Healthy'
    )


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--revision", required=True)
    p.add_argument("--image", required=True)
    p.add_argument("--namespace", default="neoversity")
    p.add_argument("--url", required=True)
    p.add_argument("--timeout", type=int, default=600)
    a = p.parse_args()
    deadline = time.monotonic() + a.timeout
    while time.monotonic() < deadline:
        try:
            app = get("argocd", "application", "django-gitops")["status"]
            deploy = get(a.namespace, "deployment", "django-app")
            if delivery_ready(app, deploy, a.revision, a.image):
                request = urllib.request.Request(a.url.rstrip("/") + "/health/", headers={"Host": "localhost"})
                with urllib.request.urlopen(request, timeout=10) as response:
                    health = json.load(response)
                if health.get("status") == "ok" and health.get("connected") is True and health.get("restricted_role") is True:
                    print("PASS: expected GitOps revision, image, rollout, and database health")
                    return 0
        except (subprocess.SubprocessError, OSError, ValueError, KeyError):
            pass
        time.sleep(5)
    print("FAIL: delivery verification timed out", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
