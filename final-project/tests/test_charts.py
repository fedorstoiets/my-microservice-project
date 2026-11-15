from pathlib import Path
import subprocess
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


def render(*overrides):
    command = ['helm', 'template', 'django-app', str(ROOT / 'charts/django-app'), '--set', 'config.POSTGRES_HOST=example.invalid']
    for value in overrides:
        command += ['--set', value]
    output = subprocess.check_output(command, text=True)
    return {(obj['kind'], obj['metadata']['name']): obj for obj in yaml.safe_load_all(output) if obj}


class ChartTests(unittest.TestCase):
    def test_database_is_required_for_render(self):
        result = subprocess.run(['helm', 'template', 'django-app', str(ROOT / 'charts/django-app')], capture_output=True)
        self.assertNotEqual(result.returncode, 0)

    def test_order_and_security(self):
        objects = render()
        config = objects[('ConfigMap', 'django-app-config')]
        migrate = objects[('Job', 'django-app-migrate')]
        deploy = objects[('Deployment', 'django-app')]
        self.assertLess(int(config['metadata']['annotations']['argocd.argoproj.io/sync-wave']), int(migrate['metadata']['annotations']['argocd.argoproj.io/sync-wave']))
        self.assertEqual(migrate['metadata']['annotations']['argocd.argoproj.io/hook'], 'Sync')
        for obj in [migrate, deploy]:
            pod = obj['spec']['template']['spec']
            self.assertFalse(pod['automountServiceAccountToken'])
            self.assertTrue(pod['securityContext']['runAsNonRoot'])
            self.assertTrue(pod['containers'][0]['securityContext']['readOnlyRootFilesystem'])
        self.assertEqual(deploy['spec']['template']['spec']['containers'][0]['livenessProbe']['httpGet']['path'], '/live/')
        self.assertEqual(objects[('Service', 'django-app')]['spec']['type'], 'ClusterIP')

    def test_eso_and_database_bootstrap_are_ordered(self):
        objects = render('externalSecrets.enabled=true', 'externalSecrets.rdsSecretArn=app', 'externalSecrets.djangoSecretArn=signing', 'databaseBootstrap.enabled=true', 'databaseBootstrap.adminSecretArn=admin')
        self.assertEqual(objects[('Job', 'django-db-bootstrap')]['metadata']['annotations']['argocd.argoproj.io/sync-wave'], '-2')
        self.assertEqual(objects[('ExternalSecret', 'django-rds-credentials')]['spec']['data'][0]['remoteRef']['key'], 'app')
        self.assertNotIn('ADMIN_PASSWORD', str(objects[('Deployment', 'django-app')]))

    def test_digest_overrides_mutable_tag(self):
        digest = 'sha256:' + 'a' * 64
        objects = render('image.digest=' + digest)
        image = objects[('Deployment', 'django-app')]['spec']['template']['spec']['containers'][0]['image']
        self.assertTrue(image.endswith('@' + digest))

    def test_optional_network_policy(self):
        objects = render('networkPolicy.enabled=true', 'networkPolicy.databaseCidrs[0]=10.80.4.0/24')
        self.assertIn(('NetworkPolicy', 'django-app'), objects)


if __name__ == '__main__':
    unittest.main()
