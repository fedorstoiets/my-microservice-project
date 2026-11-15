import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('database_bootstrap', ROOT / 'Django/bootstrap_database.py')
bootstrap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(bootstrap)


class BootstrapSafetyTests(unittest.TestCase):
    environment = {'POSTGRES_USER': 'fixture_app', 'POSTGRES_PASSWORD': 'fixture-password', 'POSTGRES_HOST': 'offline.invalid', 'POSTGRES_DB': 'fixture_db', 'ADMIN_USER': 'fixture_admin', 'ADMIN_PASSWORD': 'fixture-admin-password', 'POSTGRES_SSLROOTCERT': '/offline/ca'}

    def simulate(self, role=None, memberships=0, foreign_objects=0, deny_logging=False):
        conn = MagicMock()
        statements = []
        def execute(query, params=None):
            statements.append(query)
            if deny_logging:
                raise PermissionError('fixture')
            if isinstance(query, str):
                if query.startswith('SELECT current_setting'): value = (None,)
                elif query.startswith('SELECT rolsuper'): value = role
                elif query.startswith('SELECT count(*) FROM pg_auth_members'): value = (memberships,)
                elif 'FROM pg_class' in query: value = (foreign_objects,)
                else: value = None
            else: value = None
            return SimpleNamespace(fetchone=lambda: value)
        conn.execute.side_effect = execute
        connection = MagicMock()
        connection.__enter__.return_value = conn
        return connection, statements

    def test_fresh_bootstrap_is_one_transaction(self):
        connection, statements = self.simulate()
        with patch.dict(os.environ, self.environment), patch.object(bootstrap.psycopg, 'connect', return_value=connection) as connect:
            bootstrap.main()
        self.assertFalse(connect.call_args.kwargs['autocommit'])
        self.assertEqual(connect.call_args.kwargs['sslmode'], 'verify-full')
        self.assertTrue(any(not isinstance(s, str) for s in statements))

    def test_existing_privilege_ownership_or_logging_failure_prevents_writes(self):
        cases = [{'role': (False, True, False, False, False)}, {'memberships': 1}, {'foreign_objects': 2}, {'deny_logging': True}]
        for case in cases:
            with self.subTest(case=case):
                connection, statements = self.simulate(**case)
                with patch.dict(os.environ, self.environment), patch.object(bootstrap.psycopg, 'connect', return_value=connection), self.assertRaises((RuntimeError, PermissionError)):
                    bootstrap.main()
                self.assertFalse(any(not isinstance(s, str) for s in statements))
                self.assertFalse(any(isinstance(s, str) and s.startswith('REVOKE') for s in statements))
