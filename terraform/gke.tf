resource "google_container_cluster" "primary" {
  lifecycle {
    ignore_changes = [
      # Ignore changes to tags, e.g. because a management agent
      # updates these based on some ruleset managed elsewhere.
      node_config,
    ]
  }

  depends_on = [
    google_project_service.service_project_computeapi,
    google_compute_subnetwork_iam_member.container_network_user,
    google_compute_subnetwork_iam_member.cloudservices_network_user,
    google_project_iam_member.container_host_service_agent,
    google_project_iam_member.cloudservices_host_service_agent,
  ]

  name     = var.gke_cluster_name
  location = var.gke_cluster_location
  project  = data.google_project.service_project.project_id

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

  vertical_pod_autoscaling {
    enabled = true
  }
}
