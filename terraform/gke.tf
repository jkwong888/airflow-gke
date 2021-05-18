
locals {
  gke_sa_roles = [
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
    "roles/monitoring.viewer",
  ]
}

/*
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_primary_range
  region        = var.subnet_region
  project       = data.google_project.host_project.project_id
  network       = data.google_compute_network.shared_vpc.name

  private_ip_google_access = true

  dynamic "secondary_ip_range" {
    for_each = var.subnet_secondary_range
    content {
      range_name    = "${var.subnet_name}-${replace(replace(secondary_ip_range.value, ".", "-"), "/", "-")}"
      ip_cidr_range = secondary_ip_range.value
    }
  }
}
*/

resource "google_service_account" "gke_sa" {
  count = var.create_gke ? 1 : 0
  project = data.google_project.service_project.project_id
  account_id = format("%s-sa", var.gke_cluster_name)
  display_name = format("%s cluster service account", var.gke_cluster_name)
}


resource "google_compute_subnetwork_iam_member" "gke_sa_network_user" {
  count = var.create_gke ? 1 : 0
  project = data.google_project.host_project.project_id
  region = var.subnet_region
  subnetwork = local.subnet_name
  role = "roles/compute.networkUser"
  member = format("serviceAccount:%s", google_service_account.gke_sa[0].email)
}

resource "google_project_iam_member" "gke_sa_role" {
  count = var.create_gke ? length(local.gke_sa_roles) : 0
  project = data.google_project.service_project.project_id
  role = element(local.gke_sa_roles, count.index) 
  member = format("serviceAccount:%s", google_service_account.gke_sa[0].email)
}



resource "google_container_cluster" "primary" {
  count = var.create_gke ? 1 : 0
  provider = google

  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      node_config,
    ]
  }

  depends_on = [
    google_project_service.service_project_computeapi,
    google_compute_subnetwork_iam_member.gke_sa_network_user,
    google_project_iam_member.gke_sa_role,
    google_compute_subnetwork_iam_member.container_network_user,
    google_compute_subnetwork_iam_member.cloudservices_network_user,
    google_project_iam_member.container_host_service_agent,
    google_project_iam_member.cloudservices_host_service_agent,
  ]

  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  #project  = data.google_project.service_project.project_id
  project  = var.service_project_id

  release_channel  {
      channel = "REGULAR"
  }

  enable_autopilot = true

  private_cluster_config {
    enable_private_nodes = var.gke_private_cluster     # nodes have private IPs only
    enable_private_endpoint = false  # master nodes private IP only
    master_ipv4_cidr_block = var.gke_cluster_master_range
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
      display_name = "eerbody"
    }
  }

  network = data.google_compute_network.shared_vpc.self_link
  subnetwork = local.subnet_self_link

  ip_allocation_policy {
    cluster_secondary_range_name = var.gke_subnet_pods_range_name
    services_secondary_range_name = var.gke_subnet_services_range_name
  }

}

output "gke_service_account" {
  value = google_service_account.gke_sa[0].email
}
