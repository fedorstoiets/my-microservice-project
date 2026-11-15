from pathlib import Path
import importlib.util
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('package', ROOT / 'scripts/package-submission.py')
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def test_credential_and_state_exclusions(self):
        for name in ['backend.hcl', 'final-infra.tfplan', '.terraform/terraform.tfstate', 'reports/gates.json']:
            path = ROOT / name
            if path.exists():
                self.assertFalse(package.allowed(path), name)
        self.assertTrue(package.allowed(ROOT / 'Django/certs/rds-global-bundle.pem'))
        self.assertTrue(package.allowed(ROOT / '.terraform.lock.hcl'))
        self.assertTrue(package.allowed(ROOT / 'Jenkinsfile'))
        self.assertTrue(package.allowed(ROOT / 'Django/.env.example'))
        self.assertTrue(package.allowed(ROOT / 'deployments/platform/terraform.tfvars.example'))


if __name__ == '__main__':
    unittest.main()
