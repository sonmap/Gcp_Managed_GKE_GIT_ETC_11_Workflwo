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

variable "image_uri" {
  description = "Full Artifact Registry image URI including tag"
  type        = string
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "run-gcs-transfer"
}

variable "workflow_name" {
  description = "Workflows workflow name"
  type        = string
  default     = "wf-gcs-transfer"
}

variable "run_service_account_id" {
  description = "Cloud Run execution service account ID created by 01-foundation"
  type        = string
  default     = "sa-run-gcs-poc"
}

variable "workflow_service_account_id" {
  description = "Workflow execution service account ID created by 01-foundation"
  type        = string
  default     = "sa-workflow-gcs-poc"
}
