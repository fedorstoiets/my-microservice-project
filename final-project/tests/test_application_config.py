import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ApplicationConfigTests(unittest.TestCase):
    def test_production_rejects_missing_signing_secret(self):
        environment = dict(os.environ)
        for name in ['DJANGO_LOCAL_DEVELOPMENT', 'DJANGO_SECRET_KEY']:
            environment.pop(name, None)
        result = subprocess.run([sys.executable, '-c', 'import config.settings'], cwd=ROOT / 'Django', env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('DJANGO_SECRET_KEY', result.stderr)

    def test_production_rejects_wildcard_hosts(self):
        environment = dict(os.environ, DJANGO_LOCAL_DEVELOPMENT='0', DJANGO_SECRET_KEY='test-fixture-' * 8, DJANGO_ALLOWED_HOSTS='*')
        result = subprocess.run([sys.executable, '-c', 'import config.settings'], cwd=ROOT / 'Django', env=environment, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('explicit DJANGO_ALLOWED_HOSTS', result.stderr)

    def test_password_rotation_read_on_new_connection(self):
        program = '''
import os,tempfile
from pathlib import Path
from unittest.mock import patch
from config.db.base import DatabaseWrapper, PostgreSQLWrapper
with tempfile.TemporaryDirectory() as folder:
    file = Path(folder) / 'password'
    os.environ['POSTGRES_PASSWORD_FILE'] = str(file)
    wrapper = DatabaseWrapper({'OPTIONS': {}}, 'offline')
    with patch.object(PostgreSQLWrapper, 'get_connection_params', return_value={}):
        file.write_text('fixture-one')
        assert wrapper.get_connection_params()['password'] == 'fixture-one'
        file.write_text('fixture-two')
        assert wrapper.get_connection_params()['password'] == 'fixture-two'
'''
        environment = dict(os.environ, DJANGO_LOCAL_DEVELOPMENT='1', DJANGO_SETTINGS_MODULE='config.settings')
        result = subprocess.run([sys.executable, '-c', program], cwd=ROOT / 'Django', env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
