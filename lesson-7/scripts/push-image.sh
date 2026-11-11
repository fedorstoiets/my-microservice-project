#!/usr/bin/env bash
set -euo pipefail
# Call from lesson-7 directory: bash scripts/push-image.sh
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
REGION="${AWS_REGION:-us-east-2}"
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REPO="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/lesson-7-django"
# WSL on ARM64: build AMD64 image for t3.medium EKS nodes.
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"
docker buildx build --platform linux/amd64 --load -t lesson-7-django:lesson-7 "$ROOT"
docker tag lesson-7-django:lesson-7 "$REPO:lesson-7"
docker push "$REPO:lesson-7"
echo "$REPO:lesson-7"
