# take the GKE SA and allow storage object browser on the image registry bucket
resource "google_storage_bucket_iam_member" "compute_engine_default_registry_bucket" {
  depends_on = [
    google_project_service.service_project_computeapi,
    google_container_registry.registry,
  ]

  bucket = format("artifacts.%s.appspot.com", data.google_project.service_project.project_id)
  role = "roles/storage.objectViewer"
  member = format("serviceAccount:%s-compute@developer.gserviceaccount.com", data.google_project.service_project.number)
}


resource "google_container_registry" "registry" {
  depends_on = [
    google_project_service.service_project_computeapi
  ]

  project  = data.google_project.service_project.project_id
}

resource "google_sourcerepo_repository" "airflow_worker_repo" {
  depends_on = [
    google_project_service.service_project_computeapi
  ]

  name        = "airflow-worker-repo"
  project     = data.google_project.service_project.project_id
}

resource "google_cloudbuild_trigger" "airflow_worker_build" {
  # Google Git repository has been created.
  depends_on = [
    google_project_service.service_project_computeapi,
    google_sourcerepo_repository.airflow_worker_repo,
  ]

  description = "Trigger Git repository for airflow worker image"
  project     = data.google_project.service_project.project_id

  trigger_template {
    branch_name = "master"
    repo_name   = google_sourcerepo_repository.airflow_worker_repo.name
  }

  build {
    images = [
        format("gcr.io/%s/airflow-worker", data.google_project.service_project.project_id),
    ]

    step {
      name = "gcr.io/cloud-builders/docker"
      args = [
          "build",
          "-t",
          "gcr.io/${data.google_project.service_project.project_id}/airflow-worker:latest",
          "-f",
          "Dockerfile",
          "."
      ]
    }
  }

}