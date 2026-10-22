resource "google_artifact_registry_repository_iam_member" "vm_reader" {
  location   = google_artifact_registry_repository.shortener.location
  repository = google_artifact_registry_repository.shortener.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${google_service_account.backup_writer.email}"
}