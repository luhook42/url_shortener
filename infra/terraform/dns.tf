# DNS for luke-links.com, hosted at Cloudflare. Imported Nov 11 2026.
# The record points at the VM's static IP from address.tf, so DNS and the IP can't drift apart.
locals {
  cloudflare_zone_id = "d13a29d6e2fe31c9d2ef1809197ce619"
}

resource "cloudflare_dns_record" "root_a" {
  zone_id = local.cloudflare_zone_id
  name    = "luke-links.com"
  type    = "A"
  content = google_compute_address.shortener_ip.address
  ttl     = 1     # 1 means "Auto" in Cloudflare
  proxied = false # "DNS only": visitors connect straight to the VM, and Caddy handles HTTPS
}
