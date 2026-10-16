resource "google_compute_address" "shortener_ip" {
  name         = "shortener-ip"
  region       = "us-central1"
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
}