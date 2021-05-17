resource "google_project" "tutorial_project" {
  auto_create_network = false
  billing_account     = var.google_billing_account_id
  name                = var.google_default_project_id
  project_id          = var.google_default_project_id
  org_id              = local.google_organization_id
}

resource "google_project_service" "compute-engine-apis" {
  disable_on_destroy = true
  project            = google_project.tutorial_project.project_id
  service            = "compute.googleapis.com"
}

resource "google_project_service" "kubernetes-engine-apis" {
  disable_on_destroy = true
  project            = google_project.tutorial_project.project_id
  service            = "container.googleapis.com"

  depends_on = [
    google_project_service.compute-engine-apis
  ]
}

resource "google_project_service" "cloud-resource-manager-apis" {
  disable_on_destroy = true
  project            = google_project.tutorial_project.project_id
  service            = "cloudresourcemanager.googleapis.com"
}
