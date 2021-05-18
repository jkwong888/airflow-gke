terraform {
  backend "gcs" {
    bucket  = "jkwng-workshop-ongcp-co-tfstate"
    prefix = "jkwng-tf-service-project-gke"
  }

  required_providers {
    google = {
      version = "~> 3.67.0"
    }
    google-beta = {
      version = "~> 3.67.0"

    }
    null = {
      version = "~> 2.1"
    }
    random = {
      version = "~> 2.2"
    }
  }
}

provider "google" {
#  credentials = file(local.credentials_file_path)
}

provider "google-beta" {
#  credentials = file(local.credentials_file_path)
}

provider "null" {
}

provider "random" {
}
