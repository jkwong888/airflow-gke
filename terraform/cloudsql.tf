resource "google_sql_database_instance" "airflow" {
  name = "${var.gke_cluster_name}-${random_id.random.hex}"
  database_version = "MYSQL_5_7"
  region = var.subnet_region
  project = data.google_project.service_project.project_id
  deletion_protection = false

  depends_on = [
    google_service_networking_connection.private_service_connection,
  ]

  settings {
    tier = "db-n1-standard-1"
    database_flags {
      name  = "explicit_defaults_for_timestamp" 
      value = "on"
    }

    ip_configuration {
      ipv4_enabled      = false
      private_network   = data.google_compute_network.shared_vpc.id
    }
  }
}

resource "google_sql_database" "airflowdb" {
    name = "airflow"
    instance = google_sql_database_instance.airflow.name
    project = data.google_project.service_project.project_id
}

resource "google_sql_user" "airflow" {
    name = "airflow"
    instance = google_sql_database_instance.airflow.name
    project = data.google_project.service_project.project_id
    host = "%"
    password = random_password.mysql_password.result
}

resource "random_password" "mysql_password" {
  length           = 16
  special          = true
  override_special = "_%@"
}

resource "google_project_iam_member" "project" {
  project = data.google_project.service_project.project_id
  role    = "roles/cloudsql.client"
  member = format("serviceAccount:%s", google_service_account.airflow_sa.email)
}

resource "google_project_service" "cloudsql_adminapi" {
  project                    = data.google_project.service_project.project_id
  service                    = "sqladmin.googleapis.com"
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "local_file" "mysql_secret_yaml" {
  filename = "${path.module}/../manifests/secret-mysql-password.yaml"
  content = templatefile("${path.module}/templates/secret-mysql-password.yaml.tpl",
    {
        password = random_password.mysql_password.result,
    }
  )
}

output "db_ip" {
  value = google_sql_database_instance.airflow.first_ip_address
}

output "db_username" {
    value = google_sql_user.airflow.name
}

output "db_password" {
    value = random_password.mysql_password.result
}

output "db_connection_string" {
    value = google_sql_database_instance.airflow.connection_name
}