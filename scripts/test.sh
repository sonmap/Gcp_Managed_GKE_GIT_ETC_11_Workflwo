#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-pjt-c-admin}"
REGION="${REGION:-asia-northeast3}"
WORKFLOW_NAME="${WORKFLOW_NAME:-wf-gcs-transfer}"
SOURCE_BUCKET="${SOURCE_BUCKET:-${PROJECT_ID}-wf-gcs-a}"
TARGET_BUCKET="${TARGET_BUCKET:-${PROJECT_ID}-wf-gcs-b}"
TEST_ID="$(date +%Y%m%d-%H%M%S)"
LOCAL_FILE="/tmp/gcs-workflow-${TEST_ID}.txt"
SOURCE_OBJECT="input/test-${TEST_ID}.txt"
TARGET_OBJECT="output/test-${TEST_ID}.txt"

echo "GCS A -> Workflow -> Cloud Run -> GCS B TEST ${TEST_ID}" > "${LOCAL_FILE}"

printf '\n[1/4] Upload test file to GCS A\n'
gcloud storage cp "${LOCAL_FILE}" \
  "gs://${SOURCE_BUCKET}/${SOURCE_OBJECT}" \
  --project="${PROJECT_ID}"

PAYLOAD=$(cat <<EOF
{"source_bucket":"${SOURCE_BUCKET}","source_object":"${SOURCE_OBJECT}","target_bucket":"${TARGET_BUCKET}","target_object":"${TARGET_OBJECT}","execution_id":"${TEST_ID}"}
EOF
)

printf '\n[2/4] Run Workflow\n'
gcloud workflows run "${WORKFLOW_NAME}" \
  --project="${PROJECT_ID}" \
  --location="${REGION}" \
  --data="${PAYLOAD}"

printf '\n[3/4] Verify copied object\n'
gcloud storage ls --long \
  "gs://${TARGET_BUCKET}/${TARGET_OBJECT}" \
  --project="${PROJECT_ID}"

printf '\n[4/4] Read saved gcloud command result\n'
gcloud storage cat \
  "gs://${TARGET_BUCKET}/result/${TEST_ID}.json" \
  --project="${PROJECT_ID}"

echo
