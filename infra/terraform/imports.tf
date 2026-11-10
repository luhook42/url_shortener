# Temporary: brings resources created outside Terraform under its control.
# Remove these blocks after the import has been applied.
import {
  to = google_compute_firewall.default_allow_ssh
  id = "projects/project-e985c781-9e31-44bf-bee/global/firewalls/default-allow-ssh"
}
import {
  to = google_compute_firewall.default_allow_icmp
  id = "projects/project-e985c781-9e31-44bf-bee/global/firewalls/default-allow-icmp"
}
import {
  to = google_compute_firewall.default_allow_internal
  id = "projects/project-e985c781-9e31-44bf-bee/global/firewalls/default-allow-internal"
}
import {
  to = google_compute_resource_policy.daily_snapshots
  id = "projects/project-e985c781-9e31-44bf-bee/regions/us-central1/resourcePolicies/default-schedule-1"
}
import {
  to = google_compute_disk_resource_policy_attachment.vm_daily_snapshots
  id = "projects/project-e985c781-9e31-44bf-bee/zones/us-central1-a/disks/shortener-vm/default-schedule-1"
}
