resource "random_id" "fernet_key" {
  byte_length = 32
}

/*
resource "google_compute_managed_ssl_certificate" "airflow-cert" {
  name    = "airflow-cert"
  project = data.google_project.service_project.project_id
  
  managed {
    domains = [var.airflow_external_url]
  }
}
*/


resource "local_file" "airflow_helm_values_yaml" {
  filename = "${path.module}/../airflow-helm/airflow-values.yaml"
  content = templatefile("${path.module}/templates/gke-values.yaml.tpl", 
    {
      airflow_external_url = var.airflow_external_url,
      airflow_db_username = google_sql_user.airflow.name,
      airflow_gcs_bucket = google_storage_bucket.airflow_storage.name,
      airflow_external_ip = google_compute_global_address.airflow.address,
      airflow_sa = google_service_account.airflow_sa.email
      airflow_db_ip = google_sql_database_instance.airflow.first_ip_address,
      airflow_db_name = google_sql_database.airflowdb.name,
      airflow_fernet_key = random_id.fernet_key.b64_url,
      airflow_dags_git_repo = var.airflow_dags_git_repo,
      airflow_image_repo = format("gcr.io/%s/airflow-worker", data.google_project.service_project.project_id),
      redis_host = google_redis_instance.cache.host
      redis_port = google_redis_instance.cache.port
      static_ip_name = google_compute_global_address.airflow.name
      mysql_password = random_password.mysql_password.result,
      iap_client_id = google_iap_client.project_client.client_id,
      iap_client_secret = google_iap_client.project_client.secret,
    }
  )
}