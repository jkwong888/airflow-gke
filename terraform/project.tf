data "google_project" "host_project" {
  project_id = var.shared_vpc_host_project_id
}

data "google_project" "service_project" {
  project_id = var.service_project_id
}

locals {
  apis_to_enable = [
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudbuild.googleapis.com",
    "containerregistry.googleapis.com",
    "sourcerepo.googleapis.com",
  ]
}

resource "google_project_service" "service_project_computeapi" {
  count                      = length(local.apis_to_enable)
  project                    = data.google_project.service_project.project_id
  service                    = element(local.apis_to_enable, count.index)
  disable_on_destroy         = false
  disable_dependent_services = false
}


resource "google_compute_shared_vpc_service_project" "shared_vpc_attachment" {
  host_project    = data.google_project.host_project.project_id
  service_project = data.google_project.service_project.project_id

  depends_on = [
    google_project_service.service_project_computeapi,
  ]
}

