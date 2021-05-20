resource "google_service_account" "airflow_sa" {
  project = data.google_project.service_project.project_id
  account_id = "airflow-sa"
  display_name = format("%s airflow service account", var.gke_cluster_name)
}

resource "google_service_account_iam_member" "airflow_sa_role" {
  service_account_id = google_service_account.airflow_sa.name
  role = "roles/iam.workloadIdentityUser"
  member = format("serviceAccount:%s.svc.id.goog[%s/airflow]", data.google_project.service_project.project_id, var.airflow_namespace)
}

output "airflow_service_account" {
  value = google_service_account.airflow_sa.email
}

