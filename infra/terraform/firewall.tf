resource "google_compute_firewall" "allow_web_http_https" {
  name          = "allow-web-http-https"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}
# Google's default rules, created with the project and imported on Nov 10 2026.
# SSH stays open to everyone because CI deploys from GitHub's changing IPs.
# The VM only accepts keys, and monitoring.tf alerts on logins with unknown keys.
resource "google_compute_firewall" "default_allow_ssh" {
  name          = "default-allow-ssh"
  description   = "Allow SSH from anywhere"
  network       = "default"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_firewall" "default_allow_icmp" {
  name          = "default-allow-icmp"
  description   = "Allow ICMP from anywhere"
  network       = "default"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "default_allow_internal" {
  name          = "default-allow-internal"
  description   = "Allow internal traffic on the default network"
  network       = "default"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["10.128.0.0/9"]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
}
