variable "gke_cluster_node_pool_size" {
  default     = 1
  description = "Number of nodes GKE cluster node pools."
}

variable "google_billing_account_id" {
  description = "The default billing account for Google Cloud projects."
}

variable "google_default_region" {
  description = "The default Google Cloud region."
}

variable "google_default_zone" {
  description = "The default Google Cloud zone."
}

variable "google_default_project_id" {
  description = "Google Cloud default project ID."
}

variable "google_organization_id" {
  description = "The default organization ID for Google Cloud projects."
}

variable "terraform_environment_name" {
  description = "Name of the current environment."
}
