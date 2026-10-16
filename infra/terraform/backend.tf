terraform {
  backend "gcs" {
    bucket = "luhook42-shortener-tfstate-e985c781"
    prefix = "terraform/state"
  }
}