#!/usr/bin/env bash
# Build the Docker image and push it to the ECR repo created by Terraform.
# Usage: scripts/push-image.sh [tag]   (default tag: latest)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${1:-latest}"
IMAGE_NAME="py-automation"

for cmd in docker terraform aws; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done

REPO_URL="$(terraform -chdir="$ROOT/terraform" output -raw repository_url)"
REGISTRY="$(terraform -chdir="$ROOT/terraform" output -raw registry)"
REGION="$(terraform -chdir="$ROOT/terraform" output -raw aws_region)"

echo "Logging in to $REGISTRY"
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo "Building $IMAGE_NAME"
docker build -t "$IMAGE_NAME:$TAG" "$ROOT"

docker tag "$IMAGE_NAME:$TAG" "$REPO_URL:$TAG"

echo "Pushing $REPO_URL:$TAG"
docker push "$REPO_URL:$TAG"

echo "Done: $REPO_URL:$TAG"
