terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "~> 8.7"
    }
  }
}

provider "google" {
  project = "project-e985c781-9e31-44bf-bee"
  region  = "us-central1"
  zone    = "us-central1-a"
}