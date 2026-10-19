resource "google_service_account" "backup_writer" {
  account_id   = "backup-writer"
  display_name = "Nightly DB backup uploader"
}

resource "google_storage_bucket_iam_member" "backup_writer_creator" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.backup_writer.email}"
}

resource "google_storage_bucket_iam_member" "backup_writer_viewer" {
  bucket = google_storage_bucket.backups.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.backup_writer.email}"
}
