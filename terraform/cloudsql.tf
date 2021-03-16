resource "google_sql_database_instance" "airflow" {
    name = "${var.gke_cluster_name}-${random_id.random.hex}"
    database_version = "MYSQL_5_7"
    region = var.subnet_region
    project = data.google_project.service_project.project_id

    settings {
        tier = "db-n1-standard-1"
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
    password = random_password.password.result
}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "_%@"
}


output "db_username" {
    value = google_sql_user.airflow.name
}

output "db_password" {
    value = random_password.password.result
}

output "db_connection_string" {
    value = google_sql_database_instance.airflow.connection_name
}