terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 9.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 7.0, < 9.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  bucket_a_name = "${var.project_id}-wf-gcs-a"
  bucket_b_name = "${var.project_id}-wf-gcs-b"

  required_apis = toset([
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "run.googleapis.com",
    "storage.googleapis.com",
    "workflowexecutions.googleapis.com",
    "workflows.googleapis.com",
  ])
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# Workflows has a Google-managed service agent that is different from the
# user-managed Workflow runtime service account below. In some projects the
# first workflow deployment can race with automatic service-agent creation and
# fail with: "Workflows service agent does not exist".
# Generate the service identity explicitly during foundation provisioning.
resource "google_project_service_identity" "workflows" {
  provider = google-beta

  project = var.project_id
  service = "workflows.googleapis.com"

  depends_on = [google_project_service.required["workflows.googleapis.com"]]
}

resource "google_storage_bucket" "source" {
  name                        = local.bucket_a_name
  project                     = var.project_id
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy_buckets

  versioning {
    enabled = true
  }

  labels = {
    purpose = "workflow-poc-source"
    env     = "poc"
  }

  depends_on = [google_project_service.required]
}

resource "google_storage_bucket" "target" {
  name                        = local.bucket_b_name
  project                     = var.project_id
  location                    = upper(var.region)
  uniform_bucket_level_access = true
  force_destroy               = var.force_destroy_buckets

  versioning {
    enabled = true
  }

  labels = {
    purpose = "workflow-poc-target"
    env     = "poc"
  }

  depends_on = [google_project_service.required]
}

resource "google_artifact_registry_repository" "app" {
  project       = var.project_id
  location      = var.region
  repository_id = var.artifact_repository
  description   = "Cloud Run images for GCS/Workflow PoC"
  format        = "DOCKER"

  labels = {
    env     = "poc"
    purpose = "workflow-gcs-transfer"
  }

  depends_on = [google_project_service.required]
}

resource "google_service_account" "run" {
  project      = var.project_id
  account_id   = var.run_service_account_id
  display_name = "Cloud Run GCS transfer PoC"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "workflow" {
  project      = var.project_id
  account_id   = var.workflow_service_account_id
  display_name = "Workflow GCS transfer PoC"

  depends_on = [google_project_service.required]
}

# Cloud Run only reads objects from bucket A.
resource "google_storage_bucket_iam_member" "run_source_viewer" {
  bucket = google_storage_bucket.source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.run.email}"
}

# Cloud Run creates/copies result objects in bucket B.
# objectUser is used instead of bucket-level storage.admin.
resource "google_storage_bucket_iam_member" "run_target_object_user" {
  bucket = google_storage_bucket.target.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.run.email}"
}
