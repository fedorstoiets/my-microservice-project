import os
from pathlib import Path
from django.db.backends.postgresql.base import DatabaseWrapper as PostgreSQLWrapper


class DatabaseWrapper(PostgreSQLWrapper):
    def get_connection_params(self):
        params = super().get_connection_params()
        password_file = os.environ.get("POSTGRES_PASSWORD_FILE")
        if password_file:
            params["password"] = Path(password_file).read_text().strip()
        return params
