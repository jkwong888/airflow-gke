resource "google_storage_bucket" "airflow_storage" {
  name    =   "${var.gke_cluster_name}-airflow"
  project = data.google_project.host_project.project_id
  location = var.subnet_region
}

resource "google_storage_bucket_iam_member" "gke_sa_object_admin" {
  bucket = google_storage_bucket.airflow_storage.name
  role = "roles/storage.objectAdmin"
  member = format("serviceAccount:%s", google_service_account.gke_sa[0].email)
}

resource "google_storage_bucket_iam_member" "gke_sa_object_legacyBucketReader" {
  bucket = google_storage_bucket.airflow_storage.name
  role = "roles/storage.legacyBucketReader"
  member = format("serviceAccount:%s", google_service_account.gke_sa[0].email)
}

output "gcs_bucket_name" {
    value = google_storage_bucket.airflow_storage.name
}