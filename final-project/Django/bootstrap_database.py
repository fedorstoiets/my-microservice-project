"""Fresh-environment role bootstrap. Requires explicit database mutation approval."""
import os
import sys
import psycopg
from psycopg import sql


def main():
    # Deliberate, idempotent database mutations; execute only after deployment authorization.
    app_user = os.environ["POSTGRES_USER"]
    with psycopg.connect(host=os.environ["POSTGRES_HOST"], dbname=os.environ["POSTGRES_DB"],
                        user=os.environ["ADMIN_USER"], password=os.environ["ADMIN_PASSWORD"],
                        sslmode="verify-full", sslrootcert=os.environ["POSTGRES_SSLROOTCERT"],
                        connect_timeout=10, autocommit=False) as conn:
        # Fail before any credential DDL if safe session logging cannot be established.
        conn.execute("SET LOCAL log_statement = 'none'")
        conn.execute("SET LOCAL log_min_error_statement = 'panic'")
        conn.execute("SET LOCAL log_min_duration_statement = -1")
        conn.execute("SET LOCAL log_min_duration_sample = -1")
        conn.execute("SET LOCAL log_transaction_sample_rate = 0")
        audit = conn.execute("SELECT current_setting('pgaudit.log', true)").fetchone()[0]
        if audit and audit.lower() not in ('none', ''):
            raise RuntimeError("Audit logging requires a separately reviewed credential-logging policy")
        exists = conn.execute("SELECT rolsuper, rolcreaterole, rolcreatedb, rolreplication, rolbypassrls FROM pg_roles WHERE rolname = %s", (app_user,)).fetchone()
        memberships = conn.execute("SELECT count(*) FROM pg_auth_members m JOIN pg_roles r ON r.oid=m.member WHERE r.rolname=%s", (app_user,)).fetchone()[0]
        if memberships:
            raise RuntimeError("Refuse existing application role memberships")
        if exists and any(exists):
            raise RuntimeError("Refuse privileged existing application role")
        foreign_objects = conn.execute("""SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
            JOIN pg_roles r ON r.oid = c.relowner
            WHERE n.nspname = 'public' AND c.relkind IN ('r','p','S','v','m','f') AND r.rolname <> %s""", (app_user,)).fetchone()[0]
        if foreign_objects:
            raise RuntimeError("Existing schema ownership requires a separately reviewed transition")
        if not exists:
            conn.execute(sql.SQL("CREATE ROLE {} LOGIN").format(sql.Identifier(app_user)))
        conn.execute(sql.SQL("ALTER ROLE {} PASSWORD {}").format(sql.Identifier(app_user), sql.Literal(os.environ["POSTGRES_PASSWORD"])))
        conn.execute(sql.SQL("GRANT CONNECT, TEMPORARY ON DATABASE {} TO {}").format(sql.Identifier(os.environ["POSTGRES_DB"]), sql.Identifier(app_user)))
        conn.execute(sql.SQL("GRANT USAGE, CREATE ON SCHEMA public TO {}").format(sql.Identifier(app_user)))
        conn.execute("REVOKE CREATE ON SCHEMA public FROM PUBLIC")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print("Database bootstrap failed: " + type(error).__name__ + "; inspect connectivity/grants privately", file=sys.stderr)
        sys.exit(1)
