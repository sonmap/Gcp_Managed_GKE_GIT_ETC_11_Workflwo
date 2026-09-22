terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 7.0, < 9.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  run_sa_email      = "${var.run_service_account_id}@${var.project_id}.iam.gserviceaccount.com"
  workflow_sa_email = "${var.workflow_service_account_id}@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_cloud_run_v2_service" "transfer" {
  project  = var.project_id
  name     = var.cloud_run_service_name
  location = var.region

  # PoC: public network endpoint, IAM-authenticated only.
  # No roles/run.invoker is granted to allUsers.
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  scaling {
    max_instance_count = 2
  }

  template {
    service_account = local.run_sa_email
    timeout         = "300s"
    max_instance_request_concurrency = 5

    scaling {
      min_instance_count = 0
      max_instance_count = 2
    }

    containers {
      image = var.image_uri

      resources {
        limits = {
          cpu    = "1"
          memory = "1Gi"
        }
      }

      env {
        name  = "APP_ENV"
        value = "poc"
      }
    }
  }
}

resource "google_cloud_run_v2_service_iam_member" "workflow_invoker" {
  project  = var.project_id
  location = google_cloud_run_v2_service.transfer.location
  name     = google_cloud_run_v2_service.transfer.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${local.workflow_sa_email}"
}

resource "google_workflows_workflow" "transfer" {
  project         = var.project_id
  name            = var.workflow_name
  region          = var.region
  description     = "GCS A -> Cloud Run -> GCS B transfer PoC"
  service_account = "projects/${var.project_id}/serviceAccounts/${local.workflow_sa_email}"

  deletion_protection = false
  call_log_level       = "LOG_ERRORS_ONLY"

  labels = {
    env     = "poc"
    purpose = "gcs-transfer"
  }

  source_contents = templatefile(
    "${path.module}/workflow.yaml.tftpl",
    {
      cloud_run_url = google_cloud_run_v2_service.transfer.uri
    }
  )

  depends_on = [google_cloud_run_v2_service_iam_member.workflow_invoker]
}
