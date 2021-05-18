resource "local_file" "airflow_helm_values_yaml" {
  filename = "${path.module}/../airflow-helm/airflow-values.yaml"
  content = templatefile("${path.module}/templates/gke-values.yaml.tpl", 
    {
      airflow_db_username = google_sql_user.airflow.name,
      airflow_gcs_bucket = google_storage_bucket.airflow_storage.name,
      airflow_external_ip = google_compute_global_address.airflow.address,
      airflow_sa = google_service_account.airflow_sa.email
      airflow_db_ip = google_sql_database_instance.airflow.first_ip_address,
      airflow_db_name = google_sql_database.airflowdb.name,
      airflow_dags_git_repo = var.airflow_dags_git_repo,
      redis_host = google_redis_instance.cache.host
      redis_port = google_redis_instance.cache.port
      static_ip_name = google_compute_global_address.airflow.name
    }
  )
}