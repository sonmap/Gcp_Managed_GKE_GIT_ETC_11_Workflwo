#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:-pjt-c-admin}"
REGION="${REGION:-asia-northeast3}"
FOUNDATION_DIR="${ROOT_DIR}/terraform/01-foundation"
RUNTIME_DIR="${ROOT_DIR}/terraform/02-runtime"

IMAGE_URI="${IMAGE_URI:-asia-northeast3-docker.pkg.dev/${PROJECT_ID}/ar-wf-gcs-poc/gcs-transfer:1.0.0}"

printf '\n[1/2] Destroy runtime\n'
terraform -chdir="${RUNTIME_DIR}" init
terraform -chdir="${RUNTIME_DIR}" destroy -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="image_uri=${IMAGE_URI}"

printf '\n[2/2] Destroy foundation\n'
terraform -chdir="${FOUNDATION_DIR}" init
terraform -chdir="${FOUNDATION_DIR}" destroy -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}"
