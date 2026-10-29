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

resource "google_monitoring_uptime_check_config" "health" {
  display_name = "Shortener /health"
  timeout      = "10s"
  period       = "300s"

  http_check {
    path         = "/health"
    port         = 443
    use_ssl      = true
    validate_ssl = true

    accepted_response_status_codes {
      status_class = "STATUS_CLASS_2XX"
    }
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = "project-e985c781-9e31-44bf-bee"
      host       = "luke-links.com"
    }
  }

  content_matchers {
    content = "ok"
    matcher = "CONTAINS_STRING"
  }
}

resource "google_monitoring_alert_policy" "site_down" {
  display_name = "Shortener site is down"
  combiner     = "OR"

  conditions {
    display_name = "Health check failing from more than one location"
    condition_threshold {
      filter          = "metric.type = \"monitoring.googleapis.com/uptime_check/check_passed\" AND metric.labels.check_id = \"${google_monitoring_uptime_check_config.health.uptime_check_id}\" AND resource.type = \"uptime_url\""
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "300s"

      aggregations {
        alignment_period     = "1200s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.*"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "https://luke-links.com/health is failing. Check: `curl -i https://luke-links.com/health`, then on the VM `sudo docker ps` and `sudo docker compose logs --tail 50 caddy web`. If the VM is stopped: `gcloud compute instances start shortener-vm --zone us-central1-a`."
  }
}
