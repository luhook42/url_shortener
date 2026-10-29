resource "google_project_iam_member" "vm_log_writer" {
  project = "project-e985c781-9e31-44bf-bee"
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.backup_writer.email}"
}

resource "google_project_iam_member" "vm_metric_writer" {
  project = "project-e985c781-9e31-44bf-bee"
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.backup_writer.email}"
}
