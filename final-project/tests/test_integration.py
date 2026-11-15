import copy
import importlib.util
from pathlib import Path
import re
import shlex
import subprocess
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class PipelineIntegrationTests(unittest.TestCase):
    def test_real_lookup_command_matches_cli(self):
        pipeline = (ROOT / 'Jenkinsfile').read_text()
        command = re.search(r"ci-ecr.py lookup ([^']+)", pipeline).group(1)
        args = load('ci-ecr').parser().parse_args(['lookup', *shlex.split(command)])
        self.assertEqual(args.operation, 'lookup')
        self.assertEqual(args.tag, '$SOURCE_COMMIT')

    def test_agent_uid_and_builder_exception(self):
        text = re.findall(r'yaml """(.*?)"""', (ROOT / 'Jenkinsfile').read_text(), re.S)[0]
        pod = yaml.safe_load(re.sub(r'\$\{[^}]+\}', 'offline-fixture', text))
        containers = {c['name']: c for c in pod['spec']['containers']}
        self.assertEqual(containers['jnlp']['securityContext']['runAsUser'], 1000)
        self.assertTrue(containers['jnlp']['securityContext']['runAsNonRoot'])
        self.assertEqual(pod['spec']['securityContext']['runAsUser'], 10001)
        self.assertEqual(containers['tools']['securityContext']['runAsUser'], 1000)
        self.assertEqual(containers['kaniko']['securityContext']['runAsUser'], 0)
        self.assertFalse(pod['spec']['automountServiceAccountToken'])

    def test_delivery_rejects_scaled_to_zero_stale_and_partial_rollouts(self):
        ready = load('verify-delivery').delivery_ready
        app = {'sync': {'revision': 'expected', 'status': 'Synced'}, 'health': {'status': 'Healthy'}}
        deploy = {'metadata': {'generation': 3}, 'spec': {'replicas': 2, 'template': {'spec': {'containers': [{'image': 'expected-image'}]}}},
                  'status': {'observedGeneration': 3, 'replicas': 2, 'updatedReplicas': 2, 'availableReplicas': 2, 'readyReplicas': 2}}
        self.assertTrue(ready(app, deploy, 'expected', 'expected-image'))
        for field, value in [('observedGeneration', 2), ('replicas', 3), ('readyReplicas', 1)]:
            bad = copy.deepcopy(deploy);bad['status'][field] = value
            self.assertFalse(ready(app, bad, 'expected', 'expected-image'))
        bad = copy.deepcopy(deploy);bad['spec']['replicas'] = 0
        self.assertFalse(ready(app, bad, 'expected', 'expected-image'))
        self.assertFalse(ready(app, deploy, 'old', 'expected-image'))

    def test_argo_installation_does_not_authorize_sync(self):
        command = ['helm', 'template', 'apps', str(ROOT / 'modules/argo_cd/charts/applications'), '--set', 'rdsEndpoint=offline.invalid']
        application = yaml.safe_load(subprocess.check_output(command, text=True))
        self.assertNotIn('automated', application['spec']['syncPolicy'])
        application = yaml.safe_load(subprocess.check_output(command + ['--set', 'enableAutoSync=true'], text=True))
        self.assertTrue(application['spec']['syncPolicy']['automated']['enabled'])
        self.assertFalse(application['spec']['syncPolicy']['automated']['prune'])

class SecurityPlanReviewTests(unittest.TestCase):
    def test_replacements_and_unrelated_rds_changes_are_rejected(self):
        review = load('review-security-plan').review
        base = {'format_version': '1.2', 'terraform_version': '1.14.0', 'planned_values': {'root_module': {}}, 'complete': True, 'resource_changes': []}
        self.assertFalse(review(base))
        self.assertTrue(review({}))
        self.assertTrue(review(dict(base, resource_changes=[{'address': 'fixture', 'change': {'actions': ['no-op'], 'importing': {'id': 'fixture'}}}])))
        for address, actions in [('module.rds[0].aws_db_instance.standard[0]', ['update']), ('module.eks.aws_eks_cluster.main', ['delete', 'create'])]:
            self.assertTrue(review(dict(base, resource_changes=[{'address': address, 'change': {'actions': actions}}])))

    def test_immutable_ecr_change_is_scoped(self):
        review = load('review-security-plan').review
        item = {'address': 'module.ecr.aws_ecr_repository.main', 'change': {'actions': ['update'], 'before': {'id': 'fixture', 'image_tag_mutability': 'MUTABLE'}, 'after': {'id': 'fixture', 'image_tag_mutability': 'IMMUTABLE'}}}
        plan = {'format_version': '1.2', 'terraform_version': '1.14.0', 'planned_values': {'root_module': {}}, 'complete': True, 'resource_changes': [item]}
        self.assertFalse(review(plan))
        item['change']['after']['force_delete'] = True
        self.assertTrue(review(plan))
