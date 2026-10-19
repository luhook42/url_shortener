## GCP resources (Terraform)

The cloud resources are defined in `terraform/`: the VM, the reserved IP, the backup bucket, the `backup-writer` service account and its bucket permissions, and the port 4567 firewall rule. Change them in code (edit the `.tf` file, run `plan`, then `apply`), not in the console.

Terraform state lives in the GCS bucket `luhook42-shortener-tfstate-e985c781` (prefix `terraform/state`). That bucket was created by hand as the bootstrap, so it is not in Terraform yet.

First-time setup on a new machine:

1. Install Terraform and run `gcloud auth application-default login`.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and put your current public IP in it as a /32 (this file is git-ignored).
3. Run `terraform -chdir=infra/terraform init`, then `plan`. It should say `No changes`.

Things to know:

- The VM has `prevent_destroy = true`, so Terraform refuses any plan that would delete or replace it. If a plan shows `-/+` or `forces replacement`, stop and read it before doing anything.
- SSH keys in the VM's metadata are managed by `gcloud compute ssh` and are ignored by Terraform on purpose.
- Log in with `gcloud compute ssh luhook42@shortener-vm` (the repo owner), not the default account.
