terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
  }
}

provider "google" {
  project = "project-e985c781-9e31-44bf-bee"
  region  = "us-central1"
  zone    = "us-central1-a"

  # Budgets live on the billing account, not in this project. These two lines tell Google
  # to count Terraform's API calls against this project (needed when Terraform runs as you).
  user_project_override = true
  billing_project       = "project-e985c781-9e31-44bf-bee"
}