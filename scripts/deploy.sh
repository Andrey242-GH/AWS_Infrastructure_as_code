#!/usr/bin/env bash
# One command to create the ECR repo and push the image, or tear it all down.
#   scripts/deploy.sh up [tag]    terraform init/apply, then build + push image
#   scripts/deploy.sh destroy     delete the images and the ECR repo
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$ROOT/terraform"
ACTION="${1:-}"

# Lets Terraform delete the repo even when it still contains images.
export TF_VAR_force_delete=true

case "$ACTION" in
  up)
    terraform -chdir="$TF_DIR" init -input=false
    terraform -chdir="$TF_DIR" apply -input=false -auto-approve
    "$ROOT/scripts/push-image.sh" "${2:-latest}"
    ;;
  destroy)
    terraform -chdir="$TF_DIR" init -input=false
    # Apply first so force_delete is stored in state, then destroy.
    terraform -chdir="$TF_DIR" apply -input=false -auto-approve
    terraform -chdir="$TF_DIR" destroy -input=false -auto-approve
    ;;
  *)
    echo "Usage: $0 {up [tag]|destroy}" >&2
    exit 1
    ;;
esac
