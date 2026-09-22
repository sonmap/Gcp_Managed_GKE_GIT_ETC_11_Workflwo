#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${PROJECT_ID:-pjt-c-admin}"
REGION="${REGION:-asia-northeast3}"
IMAGE_TAG="${IMAGE_TAG:-1.0.0}"

FOUNDATION_DIR="${ROOT_DIR}/terraform/01-foundation"
RUNTIME_DIR="${ROOT_DIR}/terraform/02-runtime"

printf '\n[1/4] Terraform 01-foundation\n'
terraform -chdir="${FOUNDATION_DIR}" init
terraform -chdir="${FOUNDATION_DIR}" apply -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}"

IMAGE_BASE="$(terraform -chdir="${FOUNDATION_DIR}" output -raw artifact_image_base)"
IMAGE_URI="${IMAGE_BASE}:${IMAGE_TAG}"
SOURCE_BUCKET="$(terraform -chdir="${FOUNDATION_DIR}" output -raw source_bucket)"
CLOUDBUILD_STAGING="gs://${SOURCE_BUCKET}/cloudbuild-source"

printf '\n[2/4] Cloud Build -> Artifact Registry\n'
echo "IMAGE_URI=${IMAGE_URI}"
echo "CLOUDBUILD_STAGING=${CLOUDBUILD_STAGING}"

gcloud builds submit "${ROOT_DIR}/cloud-run" \
  --project="${PROJECT_ID}" \
  --region="${REGION}" \
  --gcs-source-staging-dir="${CLOUDBUILD_STAGING}" \
  --default-buckets-behavior="regional-user-owned-bucket" \
  --config="${ROOT_DIR}/cloud-run/cloudbuild.yaml" \
  --substitutions="_IMAGE_URI=${IMAGE_URI}"

printf '\n[3/4] Terraform 02-runtime\n'
terraform -chdir="${RUNTIME_DIR}" init
terraform -chdir="${RUNTIME_DIR}" apply -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="image_uri=${IMAGE_URI}"

printf '\n[4/4] Outputs\n'
terraform -chdir="${RUNTIME_DIR}" output

cat <<EOF

Deploy complete.

Next:
  ${ROOT_DIR}/scripts/test.sh
EOF
