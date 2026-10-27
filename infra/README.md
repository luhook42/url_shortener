# infra/

Everything that runs on `shortener-vm` but is not part of the app. These files are copies of what is on the VM. The VM is the source of truth until we add an install script, so if you change a file there, copy it back here.

## Layout

- `bin/deploy.sh` -> `/usr/local/bin/deploy.sh`. The only command the restricted deploy key may run. Takes `deploy <sha>` or `health`. A deploy fetches from GitHub (and carries on with the commits already on the VM if GitHub is down), pulls the image tagged with that commit from Artifact Registry, checks out the commit, runs `rake db:migrate` in the new image, then restarts `web` without building.
- `bin/backup-db.sh` -> `/usr/local/bin/backup-db.sh`. Nightly pg_dump, copy to the GCS bucket, prune local backups older than 7 days, then ping the heartbeat monitor.
- `bin/site-health.sh` -> `/usr/local/bin/site-health.sh`. Checks `localhost:4567/health` and pings the monitor (or its `/fail` URL).
- `systemd/*.service` and `systemd/*.timer` -> `/etc/systemd/system/`. `backup-db.timer` runs at 03:00 UTC daily. `site-health.timer` runs every 5 minutes.

## Not in this repo (secrets)

- `/etc/backup-db.env` and `/etc/site-health.env`: one line each, `HC_URL=<healthchecks.io ping URL>`. Owned by root, mode 600. Create them on the VM with a hidden prompt (`read -rsp`) so the URL never lands in shell history.
- The deploy private key lives only in the GitHub secret `VM_SSH_KEY`.
- The app's `.env` stays git-ignored.

## Setting up a fresh VM

1. Copy scripts: `sudo install -m 755 infra/bin/*.sh /usr/local/bin/`
2. Copy units: `sudo install -m 644 infra/systemd/* /etc/systemd/system/`
3. Let Docker pull from Artifact Registry: `sudo gcloud auth configure-docker us-central1-docker.pkg.dev` (use `sudo` because `deploy.sh` runs `sudo docker`). The VM's service account needs `artifactregistry.reader` (Terraform: `registry_access.tf`) and the `devstorage` scope.
4. Create the two env files described above (root, mode 600).
5. Enable the timers: `sudo systemctl daemon-reload && sudo systemctl enable --now backup-db.timer site-health.timer`
6. Add the deploy public key to `~/.ssh/authorized_keys` with these restrictions in front of it: `command="/usr/local/bin/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`
7. Update the `VM_KNOWN_HOSTS` GitHub secret (a new VM has a new host key).

## How a deploy works

1. A push to `main` runs CI: tests, then a build that pushes `web:<full commit sha>` to Artifact Registry (login through Workload Identity Federation, no stored key).
2. The deploy job SSHes to the VM with the restricted key and sends `deploy <sha>`.
3. `deploy.sh` pulls that exact image, runs migrations, and restarts `web`. If the pull fails, nothing changes.
4. A rollback is the same thing with an older sha (the Rollback workflow). Only commits from `c674070` on work, because older `docker-compose.yml` files have no `image:` line.
5. If GitHub is down, SSH in and run `SSH_ORIGINAL_COMMAND="deploy <sha>" /usr/local/bin/deploy.sh` for a sha that already has an image. For an emergency new change, build on the VM with `docker compose up -d --build` (no tests, tagged `:dev`).

## GCP resources (Terraform)

The cloud resources are defined in `terraform/`: the VM, the reserved IP, the backup bucket, the `backup-writer` service account and its bucket permissions, the port 4567 firewall rule, the Artifact Registry repo, the GitHub Actions identity (`ci-pusher` plus Workload Identity Federation), and `backup-writer`'s permission to pull images. Change them in code (edit the `.tf` file, run `plan`, then `apply`), not in the console.

Terraform state lives in the GCS bucket `luhook42-shortener-tfstate-e985c781` (prefix `terraform/state`). That bucket was created by hand as the bootstrap, so it is not in Terraform yet.

First-time setup on a new machine:

1. Install Terraform and run `gcloud auth application-default login`.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and put your current public IP in it as a /32 (this file is git-ignored).
3. Run `terraform -chdir=infra/terraform init`, then `plan`. It should say `No changes`.

Things to know:

- The VM has `prevent_destroy = true`, so Terraform refuses any plan that would delete or replace it. If a plan shows `-/+` or `forces replacement`, stop and read it before doing anything.
- SSH keys in the VM's metadata are managed by `gcloud compute ssh` and are ignored by Terraform on purpose.
- Log in with `gcloud compute ssh luhook42@shortener-vm` (the repo owner), not the default account.

## Keeping the VM disk from filling up

Every deploy pulls a new image tagged with its commit sha (about 900 MB each), so old images pile up. Two things keep this in check:

- `deploy.sh` runs `docker image prune -af --filter "until=72h"` after a successful deploy. It removes images older than 3 days that no container uses, so the last few deploys stay on the VM for a fast rollback. If the cleanup fails it prints a warning and the deploy still counts as successful.
- The system journal is capped at 200 MB. This is a one-time setting on the VM (it is not deployed from the repo):

        sudo mkdir -p /etc/systemd/journald.conf.d
        printf '[Journal]\nSystemMaxUse=200M\n' | sudo tee /etc/systemd/journald.conf.d/size.conf
        sudo systemctl restart systemd-journald

Check disk use with `df -h /` and `docker system df`.
