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

locals {
  # Keys allowed to log in to the VM. Fingerprints are hashes of public keys, so they are safe to commit.
  # Update this list when a key is added or rotated.
  known_ssh_keys = {
    ci_deploy_v2 = "SHA256:C0ZNYKZT93IS6Zyrfaj+Sc5VTyjmDXVrJSMDqj6bOZE"
    luke_mac     = "SHA256:ge108fA4YoiXKekIwlzxev8fIATJilLN3EOertWsRbI"
  }
}

resource "google_monitoring_alert_policy" "unknown_ssh_key" {
  display_name = "SSH login with an unknown key"
  combiner     = "OR"

  conditions {
    display_name = "Accepted publickey not from CI or Luke's Mac"
    condition_matched_log {
      filter = join(" AND ", concat([
        "logName=\"projects/project-e985c781-9e31-44bf-bee/logs/auth_log\"",
        "jsonPayload.message:\"Accepted publickey\"",
        "NOT jsonPayload.message:\"COMMAND=\"",
      ], [for fp in values(local.known_ssh_keys) : "NOT jsonPayload.message:\"${fp}\""]))
      label_extractors = {
        source_ip = "REGEXP_EXTRACT(jsonPayload.message, \"from ([0-9.]+)\")"
      }
    }
  }

  alert_strategy {
    notification_rate_limit {
      period = "300s"
    }
    auto_close = "1800s"
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "Someone logged in to shortener-vm with a key that is not the CI deploy key or Luke's Mac key. If you used the console SSH button, this was you. Otherwise, on the VM: list logins with `sudo zgrep -h 'Accepted publickey' /var/log/auth.log*`, list allowed keys with `ssh-keygen -lf ~/.ssh/authorized_keys`, and see what they ran with `sudo grep COMMAND= /var/log/auth.log`."
  }
}

# Fires when the Ops Agent stops sending metrics (found by the SSH-alone exam on Nov 10 2026:
# the agent was stopped and nothing alerted). Also fires if the VM itself is stopped.
resource "google_monitoring_alert_policy" "agent_silent" {
  display_name = "Ops Agent stopped reporting"
  combiner     = "OR"

  conditions {
    display_name = "No disk metric from the VM for 10 minutes"
    condition_absent {
      filter   = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/disk/percent_used\" AND metric.labels.device = \"/dev/sda1\" AND metric.labels.state = \"used\""
      duration = "600s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  documentation {
    mime_type = "text/markdown"
    content   = "shortener-vm stopped sending agent metrics. Check `gcloud compute instances list` (is the VM running?). On the VM: `systemctl is-active google-cloud-ops-agent` and `sudo journalctl -u google-cloud-ops-agent -n 20`. Fix: `sudo systemctl start google-cloud-ops-agent`. While the agent is down, logs and the disk alert are blind."
  }
}
