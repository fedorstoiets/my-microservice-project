import importlib.util
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name.replace('-', '_'), ROOT / 'scripts' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ContinuityTests(unittest.TestCase):
    def test_managed_changes_rejected_but_reads_allowed(self):
        review = load('check-plan').review
        base = {'format_version': '1.2', 'terraform_version': '1.14.0', 'complete': True,
                'planned_values': {'root_module': {}}, 'resource_changes': []}
        self.assertFalse(review(dict(base, resource_changes=[{'mode': 'data', 'change': {'actions': ['read']}}]), 0))
        self.assertTrue(review({}))
        self.assertTrue(review(dict(base, planned_values={})))
        self.assertTrue(review(base, 45))
        for action in [['create'], ['update'], ['delete'], ['delete', 'create']]:
            self.assertTrue(review(dict(base, resource_changes=[{'address': 'module.rds[0]', 'change': {'actions': action}}])))
        self.assertTrue(review(dict(base, complete=False)))
        self.assertTrue(review(dict(base, resource_drift=[{}])))

    def test_duplicate_owners_detected(self):
        inventory = load('state-inventory')
        base = {'id': 'db-example', 'type': 'aws_db_instance', 'owner': 'one'}
        self.assertEqual(len(inventory.duplicates([base, dict(base, owner='two')])), 1)
        self.assertEqual(inventory.duplicates([base, dict(base, id='different')]), [])

    def test_state_inventory_retains_indexed_addresses(self):
        inventory = load('state-inventory')
        state = {'resources': [{'mode': 'managed', 'module': 'module.rds[0]', 'type': 'aws_db_instance', 'name': 'standard', 'instances': [{'index_key': 0, 'attributes': {'id': 'example'}}]}]}
        self.assertEqual(next(inventory.entries(state, 'state'))['address'], 'module.rds[0].aws_db_instance.standard[0]')

    def test_jenkins_restore_rejects_path_traversal(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            archive.addfile(tarfile.TarInfo('../outside'))
        stream.seek(0)
        with tarfile.open(fileobj=stream) as archive, self.assertRaises(ValueError):
            load('jenkins-home').validate(archive)

    def test_jenkins_restore_requires_credential_material(self):
        stream = io.BytesIO()
        with tarfile.open(fileobj=stream, mode='w') as archive:
            for name in ['config.xml', 'secrets/master.key', 'secrets/hudson.util.Secret']:
                info = tarfile.TarInfo(name)
                info.size = 7
                archive.addfile(info, io.BytesIO(b'fixture'))
        stream.seek(0)
        with tarfile.open(fileobj=stream) as archive:
            prefix, _ = load('jenkins-home').validate(archive)
        self.assertEqual(prefix, '')

class RuntimeEvidenceTests(unittest.TestCase):
    def test_empty_and_terminating_pod_sets_are_not_healthy(self):
        healthy = load('verify-final').healthy_pods
        self.assertFalse(healthy({'items': []}))
        self.assertFalse(healthy({'items': [{'metadata': {'deletionTimestamp': 'fixture'}, 'status': {'phase': 'Running'}}]}))
        self.assertFalse(healthy({'items': [{'status': {'phase': 'Pending'}}]}))
        self.assertTrue(healthy({'items': [{'status': {'phase': 'Running', 'conditions': [{'type': 'Ready', 'status': 'True'}]}}]}))

    def test_unmounted_bound_claim_does_not_prove_jenkins_persistence(self):
        verify = load('verify-final')
        pod = {'metadata': {'labels': {'app.kubernetes.io/component': 'jenkins-controller'}}, 'status': {'phase': 'Running', 'conditions': [{'type': 'Ready', 'status': 'True'}]}, 'spec': {'volumes': [{'name': 'home', 'emptyDir': {}}]}}
        claims = {'items': [{'metadata': {'name': 'home'}, 'status': {'phase': 'Bound'}}]}
        self.assertFalse(verify.persistent_jenkins_ready({'items': [pod]}, claims))
        pod['spec']['volumes'] = [{'persistentVolumeClaim': {'claimName': 'home'}}]
        self.assertTrue(verify.persistent_jenkins_ready({'items': [pod]}, claims))

    def test_one_monitoring_pod_is_not_both_services(self):
        verify = load('verify-final')
        pods = {'items': [{'status': {'phase': 'Running', 'conditions': [{'type': 'Ready', 'status': 'True'}]}}]}
        grafana = {'items': [{'metadata': {'generation': 1, 'labels': {'app.kubernetes.io/name': 'grafana'}}, 'spec': {'replicas': 1}, 'status': {'observedGeneration': 1, 'readyReplicas': 1}}]}
        self.assertFalse(verify.monitoring_ready(pods, grafana, {'items': []}))


if __name__ == '__main__':
    unittest.main()
