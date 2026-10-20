resource "google_project_service" "iamcredentials" {
  service            = "iamcredentials.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sts" {
  service            = "sts.googleapis.com"
  disable_on_destroy = false
}

resource "google_service_account" "ci_pusher" {
  account_id   = "ci-pusher"
  display_name = "GitHub Actions: push images to the registry"
}

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.iamcredentials, google_project_service.sts]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub OIDC"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == 'luhook42/url_shortener' && assertion.ref == 'refs/heads/main'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account_iam_member" "ci_pusher_from_github" {
  service_account_id = google_service_account.ci_pusher.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/luhook42/url_shortener"
}

resource "google_artifact_registry_repository_iam_member" "ci_pusher_writer" {
  location   = google_artifact_registry_repository.shortener.location
  repository = google_artifact_registry_repository.shortener.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.ci_pusher.email}"
}

output "wif_provider" {
  value = google_iam_workload_identity_pool_provider.github.name
}

output "ci_pusher_email" {
  value = google_service_account.ci_pusher.email
}