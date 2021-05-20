resource "google_iap_brand" "project_brand" {

  depends_on = [
    google_project_service.service_project_computeapi,
  ]

  support_email     = var.airflow_admin_email
  application_title = "Apache Airflow"
  project           = data.google_project.service_project.project_id
}

resource "google_iap_client" "project_client" {
  display_name = "Airflow"
  brand        =  google_iap_brand.project_brand.name
}