import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]


class GitOpsTests(unittest.TestCase):
    def test_alignment_preserves_environment_values(self):
        with tempfile.TemporaryDirectory() as folder:
            checkout = Path(folder)
            subprocess.run(['git', 'init', '-q', str(checkout)], check=True)
            chart = checkout / 'charts/django-app'
            chart.mkdir(parents=True)
            (chart / 'values.yaml').write_text('config:\n  POSTGRES_HOST: private.example.invalid\n  DJANGO_ALLOWED_HOSTS: localhost,app.example.invalid\ncustomValue: retained\n')
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/update-gitops.py'), str(checkout), '--image', 'example.invalid/django@sha256:' + 'a' * 64, '--tag', 'b' * 40], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            values = yaml.safe_load((chart / 'values.yaml').read_text())
            self.assertEqual(values['config']['POSTGRES_HOST'], 'private.example.invalid')
            self.assertEqual(values['customValue'], 'retained')
            self.assertEqual(values['image']['digest'], 'sha256:' + 'a' * 64)

    def test_extra_gitops_chart_files_are_not_discarded(self):
        with tempfile.TemporaryDirectory() as folder:
            checkout = Path(folder)
            chart = checkout / 'charts/django-app'
            chart.mkdir(parents=True)
            extra = chart / 'custom-feature.yaml'
            extra.write_text('preserve me')
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/update-gitops.py'), str(checkout), '--image', 'example.invalid/django@sha256:' + 'a' * 64, '--tag', 'b' * 40], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(extra.read_text(), 'preserve me')


if __name__ == '__main__':
    unittest.main()

class GitOpsOverwriteTests(unittest.TestCase):
    def test_unreviewed_existing_template_is_preserved(self):
        with tempfile.TemporaryDirectory() as folder:
            checkout = Path(folder)
            subprocess.run(['git', 'init', '-q', str(checkout)], check=True)
            chart = checkout / 'charts/django-app'
            chart.mkdir(parents=True)
            existing = chart / 'Chart.yaml'
            existing.write_text('customized chart, preserve until reviewed')
            result = subprocess.run([sys.executable, str(ROOT / 'scripts/update-gitops.py'), str(checkout), '--image', 'example.invalid/django@sha256:' + 'a' * 64, '--tag', 'b' * 40], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(existing.read_text(), 'customized chart, preserve until reviewed')
