resource "google_compute_firewall" "allow_4567_from_my_ip" {
  name          = "allow-4567-from-my-ip"
  network       = "default"
  direction     = "INGRESS"
  priority      = 1000
  source_ranges = [var.my_ip_cidr]

  allow {
    protocol = "tcp"
    ports    = ["4567"]
  }
}

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