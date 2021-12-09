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

resource "google_project" "tutorial_project" {
  auto_create_network = false
  billing_account     = var.google_billing_account_id
  name                = var.google_default_project_id
  folder_id           = var.google_folder_id
  project_id          = var.google_default_project_id
  org_id              = var.google_folder_id != "" ? "" : local.google_organization_id
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
