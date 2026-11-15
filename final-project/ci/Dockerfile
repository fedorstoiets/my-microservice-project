FROM aquasec/trivy:0.76.2@sha256:8f6bb947dbc528902e11f2f5be52f7b519f6a39d5d148f41166f2040499768fb AS scanner
FROM python:3.12-alpine@sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89
USER root
RUN apk upgrade --no-cache && apk add --no-cache bash 'git>=2.54.1-r0' curl ca-certificates tar 'krb5-libs>=1.22.3-r0'
COPY --from=scanner /usr/local/bin/trivy /usr/local/bin/trivy
COPY ci/tool-versions.json ci/install-tools.py /opt/goaldevops/
RUN python /opt/goaldevops/install-tools.py
COPY Django/requirements.txt /opt/goaldevops/requirements.txt
COPY ci/requirements.txt /opt/goaldevops/ci-requirements.txt
RUN pip install --no-cache-dir --require-hashes -r /opt/goaldevops/requirements.txt -r /opt/goaldevops/ci-requirements.txt
RUN addgroup -g 10001 ci && adduser -D -u 10001 -G ci ci
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
USER 10001:10001
WORKDIR /home/ci
CMD ["sleep", "99d"]
