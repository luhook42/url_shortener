resource "google_monitoring_notification_channel" "email" {
  display_name = "Owner email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

resource "google_monitoring_alert_policy" "disk_high" {
  display_name = "Shortener VM disk over 80%"
  combiner     = "OR"

  conditions {
    display_name = "Root disk used percent above 80"
    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/disk/percent_used\" AND metric.labels.device = \"/dev/sda1\" AND metric.labels.state = \"used\""
      comparison      = "COMPARISON_GT"
      threshold_value = 80
      duration        = "300s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "Disk is above 80%. On the VM run: `sudo docker system df`, `sudo docker image prune -af`, `sudo du -xh / --max-depth=1 | sort -rh | head`, `sudo journalctl --disk-usage`."
  }
}
