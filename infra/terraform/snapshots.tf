# Daily boot-disk snapshots. Created in the console with the VM, imported Nov 10 2026.
# Second backup layer next to the nightly pg_dump (backup-db.timer, 03:00 UTC).
resource "google_compute_resource_policy" "daily_snapshots" {
  name   = "default-schedule-1"
  region = "us-central1"

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "19:00"
      }
    }
    retention_policy {
      max_retention_days    = 14
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }
    snapshot_properties {
      guest_flush = false
    }
  }
}

# Links the schedule to the VM's boot disk. Without it, no snapshots are taken.
resource "google_compute_disk_resource_policy_attachment" "vm_daily_snapshots" {
  name = google_compute_resource_policy.daily_snapshots.name
  disk = "shortener-vm"
  zone = "us-central1-a"
}
