resource "google_compute_firewall" "bookinfo" {
  description = "Bookinfo App rules"
  name        = "bookinfo"
  network     = google_compute_network.tutorial-vpc.name
  project     = google_project.tutorial_project.project_id

  allow {
    protocol = "tcp"
    ports    = ["22", "9080-9084"]
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

resource "google_compute_instance" "legacy-vm" {
  name         = "legacy-vm"
  machine_type = "n1-standard-1"
  project      = google_project.tutorial_project.project_id
  tags         = ["bookinfo-legacy-vm"]
  zone         = var.google_default_zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
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

  metadata_startup_script = file("${path.module}/gce-startup.sh")

  service_account {
    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    email  = google_service_account.istio_migration_gce.email
    scopes = ["cloud-platform"]
  }


}
