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