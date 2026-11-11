# DevOps Homework 4 — Docker

Three-service Docker Compose application: **Django (web) + PostgreSQL (db) + Nginx (nginx)**.

## Requirements

- Docker Engine and Docker Compose V2 (Ubuntu 24.04 / WSL2 works; ARM64 is supported by the chosen images).
- Port 80 must be free on the host. If occupied, change `NGINX_PORT` to `8080` in `.env` and open http://localhost:8080.

## Run

```bash
cp .env.example .env
# These are local development credentials only; choose different passwords for any deployment.
docker compose up -d --build
docker compose ps
```

Open **http://localhost/**. Refresh and observe the page visit counter increase (it writes to PostgreSQL).

Test via CLI:

```bash
curl -f http://localhost/
curl -f http://localhost/health/
docker compose exec web python manage.py check
docker compose exec web python manage.py showmigrations core
docker compose exec db sh -c 'psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT COUNT(*) FROM core_pagevisit;"'
```

Expected health response: `{"status":"ok","database":"postgresql","connected":true}`.

**Notes:** Compose services are called `web`, `db`, `nginx`; the proxy target is **`http://web:8000`**, not `http://django:8000`, because Docker DNS resolves service names. Django runs through Gunicorn. The entrypoint applies migrations and collects static assets. PostgreSQL data lives in the `postgres_data` named volume. `depends_on: service_healthy` makes the web service wait for PostgreSQL readiness.

## Troubleshooting

```bash
docker compose logs --tail=100 db web nginx
sudo service docker start       # if WSL Docker daemon is stopped
# If port 80 is occupied: edit .env to NGINX_PORT=8080 and visit http://localhost:8080
```

## Stop

```bash
docker compose down             # preserve database volume
# docker compose down -v        # DANGER: delete database volume, only if intended
```

## GitHub workflow

From the existing `my-microservice-project` repository, switch to the completed lesson-3 branch, then create a new branch `lesson-4` (do not recreate an existing branch). Place these files in the repository root.

```bash
git switch lesson-3
git switch -c lesson-4
git add .
git commit -m "Add Dockerized Django project with PostgreSQL and Nginx"
git push -u origin lesson-4
```

## Security scope

The provided config is designed only for a local Docker homework environment: the Nginx port is bound to `127.0.0.1`, PostgreSQL is not published, and development-only example credentials are used. For production use, configure strong secrets, HTTPS, stricter hosts, backups and production hardening.
