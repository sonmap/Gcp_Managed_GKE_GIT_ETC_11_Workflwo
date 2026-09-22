output "cloud_run_service" {
  value = google_cloud_run_v2_service.transfer.name
}

output "cloud_run_uri" {
  value = google_cloud_run_v2_service.transfer.uri
}

output "workflow_name" {
  value = google_workflows_workflow.transfer.name
}

output "workflow_region" {
  value = google_workflows_workflow.transfer.region
}
