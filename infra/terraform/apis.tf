# APIs the project billing link and the budget need (Terraform lesson part 3, Nov 2026).
# disable_on_destroy = false: removing a block from code must not switch the API off.
resource "google_project_service" "cloudbilling" {
  service            = "cloudbilling.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "billingbudgets" {
  service            = "billingbudgets.googleapis.com"
  disable_on_destroy = false
}

# Needed because user_project_override counts every Terraform API call against this project.
resource "google_project_service" "cloudresourcemanager" {
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}
