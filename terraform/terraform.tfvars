shared_vpc_host_project_id = "shared-vpc-host-project-55427"
shared_vpc_network = "shared-network"

service_project_id = "jkwng-airflow"
registry_project_id = "jkwng-cicd-274417"

create_gke = true
gke_cluster_master_range = "10.33.2.0/28"
gke_cluster_name = "airflow-central1"

subnet_name = "airflow-central1"
subnet_region = "us-central1"
subnet_primary_range = "10.33.0.0/24"

subnet_secondary_range = {
    pods = "10.34.0.0/16"
    services = "10.33.1.0/24"
}

gke_default_nodepool_max_size = 3

