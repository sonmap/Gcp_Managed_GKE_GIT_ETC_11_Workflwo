variable "project_id" {
  description = "GCP project for the PoC"
  type        = string
  default     = "pjt-c-admin"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "asia-northeast3"
}

variable "artifact_repository" {
  description = "Artifact Registry repository name"
  type        = string
  default     = "ar-wf-gcs-poc"
}

variable "run_service_account_id" {
  description = "Cloud Run execution service account ID"
  type        = string
  default     = "sa-run-gcs-poc"
}

variable "workflow_service_account_id" {
  description = "Workflows execution service account ID"
  type        = string
  default     = "sa-workflow-gcs-poc"
}

variable "force_destroy_buckets" {
  description = "PoC only: allow Terraform to delete non-empty buckets"
  type        = bool
  default     = true
}
