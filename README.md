# GCS A -> Workflows -> Cloud Run -> GCS B PoC

Target project: `pjt-c-admin`  
Region: `asia-northeast3`

## Goal

This PoC validates the following path.

```text
Cloud Shell / Admin VM
  |
  | gcloud storage cp
  v
GCS A: gs://pjt-c-admin-wf-gcs-a/input/test.txt
  |
  | gcloud workflows run
  v
Workflow: wf-gcs-transfer
  |
  | HTTP POST + OIDC
  v
Cloud Run: run-gcs-transfer
  |
  | 1. gcloud storage cp A -> B
  | 2. gcloud storage ls --format=json
  | 3. save command result JSON
  v
GCS B
  |- output/test.txt
  `- result/<execution-id>.json
```

## Network concept

The first PoC does **not** attach Cloud Run to a VPC subnet. Cloud Run only calls Google APIs such as Cloud Storage, so a VPC connector or Direct VPC egress is not required for this test.

If a later phase requires private RFC1918 access or forced VPC egress, use the existing Shared VPC subnet:

- Host project: `pjt-d-shared-base`
- Subnet: `subnet-common-admin`
- Region: `asia-northeast3`

Do not attach that subnet merely for GCS API access.

## Repository structure

```text
.
├── README.md
├── cloud-run/
│   ├── Dockerfile
│   ├── cloudbuild.yaml
│   ├── main.py
│   └── requirements.txt
├── terraform/
│   ├── 01-foundation/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── terraform.tfvars.example
│   └── 02-runtime/
│       ├── main.tf
│       ├── variables.tf
│       ├── workflow.yaml.tftpl
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── scripts/
    ├── deploy.sh
    ├── test.sh
    └── destroy.sh
```

## Resources

### 01-foundation

- Required APIs
- `gs://pjt-c-admin-wf-gcs-a`
- `gs://pjt-c-admin-wf-gcs-b`
- Artifact Registry `ar-wf-gcs-poc`
- Cloud Run service account `sa-run-gcs-poc`
- Workflows service account `sa-workflow-gcs-poc`
- Bucket-level minimum IAM

### 02-runtime

- Cloud Run `run-gcs-transfer`
- Workflows `wf-gcs-transfer`
- `roles/run.invoker` from Workflow SA to Cloud Run

## One-command deploy

Run from the repository root with an account that can create the resources in `pjt-c-admin`.

```bash
chmod +x scripts/*.sh
./scripts/deploy.sh
```

The script performs:

```text
Terraform 01-foundation
        -> Cloud Build
        -> Artifact Registry image
        -> Terraform 02-runtime
```

## Test

```bash
./scripts/test.sh
```

Or manually:

```bash
echo "GCS A to GCS B TEST" > /tmp/test.txt

gcloud storage cp /tmp/test.txt \
  gs://pjt-c-admin-wf-gcs-a/input/test.txt \
  --project=pjt-c-admin

gcloud workflows run wf-gcs-transfer \
  --project=pjt-c-admin \
  --location=asia-northeast3 \
  --data='{
    "source_bucket":"pjt-c-admin-wf-gcs-a",
    "source_object":"input/test.txt",
    "target_bucket":"pjt-c-admin-wf-gcs-b",
    "target_object":"output/test.txt"
  }'

gcloud storage ls "gs://pjt-c-admin-wf-gcs-b/**" \
  --project=pjt-c-admin
```

## IAM model

```text
sa-workflow-gcs-poc
  `- roles/run.invoker -> run-gcs-transfer

sa-run-gcs-poc
  |- roles/storage.objectViewer -> GCS A
  `- roles/storage.objectUser   -> GCS B
```

No service-account key file is used. Cloud Run uses its service identity/ADC, and Workflows invokes Cloud Run with OIDC.

## Destroy

Delete runtime first, then foundation.

```bash
./scripts/destroy.sh
```
