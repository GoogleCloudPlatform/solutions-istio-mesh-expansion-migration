resource "google_compute_network" "tutorial-vpc" {
  name                    = "${google_project.tutorial_project.project_id}-vpc"
  auto_create_subnetworks = "false"
  project                 = google_project.tutorial_project.project_id

  depends_on = [
    google_project_service.compute-engine-apis,
  ]
}

locals {
  source_cluster_pods_ip_range_name     = "${local.cluster_name}-subnet-pods"
  source_cluster_services_ip_range_name = "${local.cluster_name}-subnet-services"
}

resource "google_compute_subnetwork" "tutorial-subnet" {
  name          = "${google_project.tutorial_project.project_id}-cluster-subnet"
  region        = var.google_default_region
  network       = google_compute_network.tutorial-vpc.name
  ip_cidr_range = "10.10.0.0/24"
  project       = google_project.tutorial_project.project_id

  secondary_ip_range {
    range_name    = local.source_cluster_pods_ip_range_name
    ip_cidr_range = "192.168.0.0/19"
  }

  secondary_ip_range {
    range_name    = local.source_cluster_services_ip_range_name
    ip_cidr_range = "192.168.32.0/19"
  }

  depends_on = [
    google_project_service.compute-engine-apis,
  ]
}

resource "google_compute_global_address" "example_workload_ingress_global_address" {
  name    = "example-workload-ingress-global-ip"
  project = google_project.tutorial_project.project_id

  depends_on = [
    google_project_service.compute-engine-apis,
  ]
}
