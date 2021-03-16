data "google_project" "registry_project" {
    project_id = var.registry_project_id
}

# take the GKE SA and allow storage object browser on the image registry bucket

resource "google_storage_bucket_iam_member" "registry_bucket" {
    count = var.create_gke ? 1 : 0
    bucket = format("artifacts.%s.appspot.com", data.google_project.registry_project.project_id)
    role = "roles/storage.objectViewer"
    member = format("serviceAccount:%s", google_service_account.gke_sa[0].email)
}

resource "google_storage_bucket_iam_member" "compute_engine_default_registry_bucket" {
    bucket = format("artifacts.%s.appspot.com", data.google_project.registry_project.project_id)
    role = "roles/storage.objectViewer"
    member = format("serviceAccount:%s-compute@developer.gserviceaccount.com", data.google_project.service_project.number)
}