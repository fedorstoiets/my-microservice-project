#!/bin/sh
set -eu
# Local Compose convenience only. Kubernetes uses an ordered, single migration Job.
if [ "${DJANGO_LOCAL_DEVELOPMENT:-0}" = "1" ]; then
  python manage.py migrate --noinput
  python manage.py collectstatic --noinput
fi
exec "$@"
