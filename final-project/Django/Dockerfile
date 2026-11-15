FROM python:3.12-alpine@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1
RUN apk upgrade --no-cache && apk add --no-cache 'krb5-libs>=1.22.3-r0'
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --require-hashes -r requirements.txt
COPY . .
# Static collection uses isolated build-only settings and never contacts a database.
RUN DJANGO_LOCAL_DEVELOPMENT=1 python manage.py collectstatic --noinput \
    && chmod +x /app/entrypoint.sh \
    && addgroup -g 10001 app \
    && adduser -D -H -u 10001 -G app app \
    && chown -R 10001:10001 /app/staticfiles
USER 10001:10001
EXPOSE 8000
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "2", "--worker-tmp-dir", "/tmp"]
