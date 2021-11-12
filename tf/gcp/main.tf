# terraform apply -var="project=..."
variable project {}
variable bucket {}
variable region {default = "us-east1"}


provider "google" {
  project     = var.project
  region      = var.region
}


resource "google_service_account" "packer_account" {
  account_id   = "packer"
  display_name = "Packer Service Account"
}


locals {
    account_id = "serviceAccount:packer@${var.project}.iam.gserviceaccount.com"
}

module "iam_projects_iam" {
  source  = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 7.3"

  projects = [var.project]

  bindings = {
    "roles/secretmanager.secretAccessor" = [
       local.account_id,      
     ]

     "roles/storage.objectViewer" = [
       local.account_id,      
     ]
  
    "roles/viewer" = [
      local.account_id,      
    ]
  }
}

resource "google_secret_manager_secret" "packer-secret" {
  secret_id = "artifactdir"

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "packer-secret-version" {
  secret = google_secret_manager_secret.packer-secret.id

  secret_data = var.bucket
}