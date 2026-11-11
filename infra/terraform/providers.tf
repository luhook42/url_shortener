terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.7"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
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
# Cloudflare manages DNS for luke-links.com. The API token is read from the
# CLOUDFLARE_API_TOKEN environment variable (run `cfenv` first); it is never stored in the repo.
provider "cloudflare" {}
