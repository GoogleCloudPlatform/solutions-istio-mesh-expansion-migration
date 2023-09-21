# Copyright 2021 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

provider "google" {
  region = var.google_default_region
  zone   = var.google_default_zone
}

data "google_organization" "main_organization" {
  organization = var.google_organization_id
}

locals {
  google_organization_id = data.google_organization.main_organization.org_id

  cluster_name    = "istio-migration"
  machine_type    = "e2-standard-2"
  release_channel = "RAPID"
}

module "kubernetes-engine" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "28.0.0"

  create_service_account     = true
  horizontal_pod_autoscaling = true
  ip_range_pods              = local.source_cluster_pods_ip_range_name
  ip_range_services          = local.source_cluster_services_ip_range_name
  name                       = local.cluster_name
  network                    = google_compute_network.tutorial-vpc.name
  network_policy             = true
  project_id                 = google_project.tutorial_project.project_id
  region                     = var.google_default_region
  release_channel            = local.release_channel
  remove_default_node_pool   = true
  subnetwork                 = google_compute_subnetwork.tutorial-subnet.name

  node_pools = [
    {
      auto_repair  = true
      auto_upgrade = true
      machine_type = local.machine_type
      name         = "${local.cluster_name}-node-pool"
      node_count   = var.gke_cluster_node_pool_size
    }
  ]

  # Grant the cloud-platform scope, and use IAM to limit access
  # See: https://cloud.google.com/compute/docs/access/service-accounts#associating_a_service_account_to_an_instance
  node_pools_oauth_scopes = {
    all = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  depends_on = [
    google_project_service.cloud-resource-manager-apis,
    google_project_service.compute-engine-apis,
    google_project_service.kubernetes-engine-apis,
  ]
}

resource "google_project_iam_member" "monitoring_viewer" {
  member  = "serviceAccount:${module.kubernetes-engine.service_account}"
  project = google_project.tutorial_project.project_id
  role    = "roles/monitoring.viewer"
}

resource "google_project_iam_member" "monitoring_metric_writer" {
  member  = "serviceAccount:${module.kubernetes-engine.service_account}"
  project = google_project.tutorial_project.project_id
  role    = "roles/monitoring.metricWriter"
}

resource "google_project_iam_member" "logging_log_writer" {
  member  = "serviceAccount:${module.kubernetes-engine.service_account}"
  project = google_project.tutorial_project.project_id
  role    = "roles/logging.logWriter"
}
