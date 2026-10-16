resource "google_storage_bucket" "backups" {
  name                        = "luhook42-shortener-backups-e985c781"
  location                    = "US-CENTRAL1"
  storage_class               = "STANDARD"
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }
}

import {
  to = google_storage_bucket.backups
  id = "project-e985c781-9e31-44bf-bee/luhook42-shortener-backups-e985c781"
}