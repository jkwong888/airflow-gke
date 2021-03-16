locals {
    subnet_name = var.create_subnet ? google_compute_subnetwork.subnet[0].name : data.google_compute_subnetwork.subnet[0].name
    subnet_self_link = var.create_subnet ? google_compute_subnetwork.subnet[0].self_link : data.google_compute_subnetwork.subnet[0].self_link
}

data "google_compute_network" "shared_vpc" {
  name =  var.shared_vpc_network
  project = data.google_project.host_project.project_id
}

resource "google_compute_subnetwork" "subnet" {
  count         = var.create_subnet ? 1 : 0
  name          = var.subnet_name
  ip_cidr_range = var.subnet_primary_range
  region        = var.subnet_region
  project       = data.google_project.host_project.project_id
  network       = data.google_compute_network.shared_vpc.name

  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.subnet_secondary_range
    content {
      range_name    = secondary_ip_range.key
      ip_cidr_range = secondary_ip_range.value
    }
  }
}

resource "google_compute_subnetwork" "additional_subnet" {
  count         = var.create_subnet ? length(var.additional_subnets) : 0
  name          = var.additional_subnets[count.index].name
  ip_cidr_range = var.additional_subnets[count.index].primary_range
  region        = var.additional_subnets[count.index].region
  project       = data.google_project.host_project.project_id
  network       = data.google_compute_network.shared_vpc.name

  private_ip_google_access = true
}

data "google_compute_subnetwork" "subnet" {
  count         = var.create_subnet ? 0 : 1
  name          = var.subnet_name
  region        = var.subnet_region
  project       = data.google_project.host_project.project_id
}



resource "google_project_iam_member" "cloudservices_host_service_agent" {
  project = data.google_project.host_project.project_id
  role = "roles/container.hostServiceAgentUser"
  member = format("serviceAccount:%d@cloudservices.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_project_iam_member" "container_host_service_agent" {
  depends_on = [
    google_project_service.service_project_computeapi
  ]
  project = data.google_project.host_project.project_id
  role = "roles/container.hostServiceAgentUser"
  member = format("serviceAccount:service-%d@container-engine-robot.iam.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_compute_subnetwork_iam_member" "cloudservices_network_user" {
  project = data.google_project.host_project.project_id
  region = var.subnet_region
  subnetwork = local.subnet_name
  role = "roles/compute.networkUser"
  member = format("serviceAccount:%d@cloudservices.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_compute_subnetwork_iam_member" "container_network_user" {
  project = data.google_project.host_project.project_id
  region = var.subnet_region
  subnetwork = local.subnet_name
  role = "roles/compute.networkUser"
  member = format("serviceAccount:service-%d@container-engine-robot.iam.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_compute_subnetwork_iam_member" "container_network_user_additional" {
  count       = var.create_subnet ? length(var.additional_subnets) : 0
  project     = data.google_project.host_project.project_id
  region      = google_compute_subnetwork.additional_subnet[count.index].region
  subnetwork  = google_compute_subnetwork.additional_subnet[count.index].name
  role        = "roles/compute.networkUser"
  member      = format("serviceAccount:service-%d@container-engine-robot.iam.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_compute_subnetwork_iam_member" "cloudservices_network_user_additional" {
  count       = var.create_subnet ? length(var.additional_subnets) : 0
  project     = data.google_project.host_project.project_id
  region      = google_compute_subnetwork.additional_subnet[count.index].region
  subnetwork  = google_compute_subnetwork.additional_subnet[count.index].name
  role        = "roles/compute.networkUser"
  member      = format("serviceAccount:%d@cloudservices.gserviceaccount.com", data.google_project.service_project.number)
}

resource "google_compute_address" "airflow" {
  name = "airflow-public"
  project     = data.google_project.service_project.project_id
  region        = var.subnet_region

}

output "airflow_ip" {
  value = google_compute_address.airflow.address
}