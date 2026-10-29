resource "google_compute_instance" "shortener_vm" {
  name                       = "shortener-vm"
  machine_type               = "e2-medium"
  zone                       = "us-central1-a"
  allow_stopping_for_update  = true
  key_revocation_action_type = "NONE"

  metadata = {
    enable-osconfig = "TRUE"
  }

  boot_disk {
    auto_delete = true
    device_name = "shortener-vm"
    mode        = "READ_WRITE"
    source      = "https://www.googleapis.com/compute/v1/projects/project-e985c781-9e31-44bf-bee/zones/us-central1-a/disks/shortener-vm"

    initialize_params {
      architecture      = "X86_64"
      image             = "https://www.googleapis.com/compute/v1/projects/debian-cloud/global/images/debian-13-trixie-v20261006"
      size              = 20
      type              = "pd-balanced"
      resource_policies = ["https://www.googleapis.com/compute/v1/projects/project-e985c781-9e31-44bf-bee/regions/us-central1/resourcePolicies/default-schedule-1"]
    }
  }

  network_interface {
    network    = "https://www.googleapis.com/compute/v1/projects/project-e985c781-9e31-44bf-bee/global/networks/default"
    subnetwork = "https://www.googleapis.com/compute/v1/projects/project-e985c781-9e31-44bf-bee/regions/us-central1/subnetworks/default"
    network_ip = "10.128.0.2"

    access_config {
      nat_ip       = google_compute_address.shortener_ip.address
      network_tier = "PREMIUM"
    }
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    preemptible         = false
    provisioning_model  = "STANDARD"
  }

  service_account {
    email = google_service_account.backup_writer.email
    scopes = [
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
    ]
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = false
    enable_vtpm                 = true
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata["ssh-keys"]]
  }
}