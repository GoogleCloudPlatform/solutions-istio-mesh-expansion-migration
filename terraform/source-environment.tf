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

resource "google_compute_firewall" "bookinfo" {
  description = "Bookinfo App rules"
  name        = "bookinfo"
  network     = google_compute_network.tutorial-vpc.name
  project     = google_project.tutorial_project.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "9080"]
  }

  target_tags = ["bookinfo-legacy-vm"]
}

resource "google_service_account" "istio_migration_gce" {
  account_id   = "istio-migration-gce"
  display_name = "istio-migration-gce"
  project      = google_project.tutorial_project.project_id
}

resource "google_project_iam_member" "compute_viewer" {
  member  = "serviceAccount:${google_service_account.istio_migration_gce.email}"
  project = google_project.tutorial_project.project_id
  role    = "roles/compute.viewer"
}

resource "google_compute_instance" "source-environment-instance" {
  #ts:skip=AC_GCP_0041 Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
  for_each = toset(["productpage", "details", "ratings", "reviews"])

  name         = "source-environment-${each.key}"
  machine_type = "n1-standard-1"
  project      = google_project.tutorial_project.project_id
  tags         = ["bookinfo-legacy-vm", each.key]
  zone         = var.google_default_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = "10"
      type  = "pd-ssd"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.tutorial-subnet.self_link

    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = templatefile("${path.module}/gce-startup.sh",
    {
      docker_compose_version = var.docker_compose_version
      istio_version          = var.istio_version
    }
  )

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    # See https://cloud.google.com/compute/docs/access/service-accounts#accesscopesiam for details
    email  = google_service_account.istio_migration_gce.email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }
}
