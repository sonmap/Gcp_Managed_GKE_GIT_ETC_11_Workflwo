output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

output "source_bucket" {
  value = google_storage_bucket.source.name
}

output "target_bucket" {
  value = google_storage_bucket.target.name
}

output "artifact_repository" {
  value = google_artifact_registry_repository.app.repository_id
}

output "artifact_image_base" {
  value = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.app.repository_id}/gcs-transfer"
}

output "run_service_account" {
  value = google_service_account.run.email
}

output "workflow_service_account" {
  value = google_service_account.workflow.email
}

output "workflows_service_agent" {
  description = "Google-managed Cloud Workflows service agent"
  value       = google_project_service_identity.workflows.email
}
