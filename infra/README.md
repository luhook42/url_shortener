# infra/

Everything that runs on `shortener-vm` but is not part of the app. The repo is the source of truth: change a file here, merge it, then install it with `bin/sync-vm.sh apply`. Don't edit these files on the VM directly; `bin/sync-vm.sh check` shows any drift.

## Layout

Files under `vm/` sit at the same path they have on the VM: `vm/usr/local/bin/backup-db.sh` is `/usr/local/bin/backup-db.sh`.

- `vm/usr/local/bin/deploy.sh`: the only command the restricted deploy key may run. Takes `deploy <sha>` or `health`. A deploy fetches from GitHub (and carries on with the commits already on the VM if GitHub is down), pulls the image tagged with that commit from Artifact Registry, runs `rake db:migrate` in the new image, checks out the commit, then restarts `web` without building. If the commit changes `Caddyfile`, it also recreates `caddy` so the new config is loaded.
- `vm/usr/local/bin/backup-db.sh`: nightly pg_dump, copy to the GCS bucket, prune local backups older than 7 days, then ping the heartbeat monitor.
- `vm/usr/local/bin/site-health.sh`: checks `localhost:4567/health` and pings the monitor (or its `/fail` URL).
- `vm/etc/systemd/system/`: `backup-db.service` and `.timer` (03:00 UTC daily), `site-health.service` and `.timer` (every 5 minutes).
- `vm/etc/systemd/journald.conf.d/size.conf`: caps the system journal at 200 MB.
- `vm/etc/google-cloud-ops-agent/config.yaml`: adds `/var/log/auth.log` (SSH logins, sudo) to the logs sent to Cloud Logging.
- `bin/sync-vm.sh` (run on your Mac) and `bin/vm-apply.sh` (runs on the VM): compare and install the files above.

## Installing and checking server files

- `infra/bin/sync-vm.sh check` (from your Mac) shows what differs between the repo and the VM, and changes nothing. Run it monthly to catch drift.
- `infra/bin/sync-vm.sh apply` saves each changed file to `/var/backups/vm-config/<time>/` on the VM, installs the repo version owned by root (755 in `bin/`, 644 elsewhere), then reloads systemd or restarts journald and the Ops Agent if their files changed.
- Change the repo first and merge, then run `apply` from `main`.
- Only `/etc` and `/usr/local/bin` are allowed. Secrets are never copied.

## Not in this repo (secrets)

- `/etc/backup-db.env` and `/etc/site-health.env`: one line each, `HC_URL=<healthchecks.io ping URL>`. Owned by root, mode 600. Create them on the VM with a hidden prompt (`read -rsp`) so the URL never lands in shell history.
- The deploy private key lives only in the GitHub secret `VM_SSH_KEY`.
- The app's `.env` stays git-ignored.

## Setting up a fresh VM

1. Install the server files from your Mac: `infra/bin/sync-vm.sh apply`.
2. Let Docker pull from Artifact Registry: `sudo gcloud auth configure-docker us-central1-docker.pkg.dev` (use `sudo` because `deploy.sh` runs `sudo docker`). The VM's service account needs `artifactregistry.reader` (Terraform: `registry_access.tf`) and the `devstorage` scope.
3. Create the two env files described above (root, mode 600).
4. Enable the timers: `sudo systemctl enable --now backup-db.timer site-health.timer`
5. Add the deploy public key to `~/.ssh/authorized_keys` with these restrictions in front of it: `command="/usr/local/bin/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`
6. Update the `VM_KNOWN_HOSTS` GitHub secret (a new VM has a new host key).

## How a deploy works

1. A push to `main` runs CI: tests, then a build that pushes `web:<full commit sha>` to Artifact Registry (login through Workload Identity Federation, no stored key).
2. The deploy job SSHes to the VM with the restricted key and sends `deploy <sha>`.
3. `deploy.sh` pulls that exact image, runs migrations, checks out the commit, and restarts `web`. If the pull or a migration fails, the checkout and running containers stay on the old commit.
4. A rollback is the same thing with an older sha (the Rollback workflow). Only commits from `c674070` on work, because older `docker-compose.yml` files have no `image:` line.
5. If GitHub is down, SSH in and run `SSH_ORIGINAL_COMMAND="deploy <sha>" /usr/local/bin/deploy.sh` for a sha that already has an image. For an emergency new change, build on the VM with `docker compose up -d --build` (no tests, tagged `:dev`).

## GCP resources (Terraform)

The cloud resources are defined in `terraform/`: the VM, the reserved IP, the backup bucket, the `backup-writer` service account and its bucket permissions, the port 80/443 firewall rule (`web` itself listens only on 127.0.0.1:4567, behind Caddy), the Artifact Registry repo, the GitHub Actions identity (`ci-pusher` plus Workload Identity Federation), and `backup-writer`'s permission to pull images. Change them in code (edit the `.tf` file, run `plan`, then `apply`), not in the console.

Terraform state lives in the GCS bucket `luhook42-shortener-tfstate-e985c781` (prefix `terraform/state`). That bucket was created by hand as the bootstrap, so it is not in Terraform yet.

First-time setup on a new machine:

1. Install Terraform and run `gcloud auth application-default login`.
2. Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` and set `alert_email` to the address that should receive monitoring alerts (this file is git-ignored).
3. Run `terraform -chdir=infra/terraform init`, then `plan`. It should say `No changes`.

Things to know:

- The VM has `prevent_destroy = true`, so Terraform refuses any plan that would delete or replace it. If a plan shows `-/+` or `forces replacement`, stop and read it before doing anything.
- SSH keys in the VM's metadata are managed by `gcloud compute ssh` and are ignored by Terraform on purpose.
- Log in with `gcloud compute ssh luhook42@shortener-vm` (the repo owner), not the default account.

## Keeping the VM disk from filling up

Every deploy pulls a new image tagged with its commit sha (about 900 MB each), so old images pile up. Two things keep this in check:

- `deploy.sh` runs `docker image prune -af --filter "until=72h"` after a successful deploy. It removes images older than 3 days that no container uses, so the last few deploys stay on the VM for a fast rollback. If the cleanup fails it prints a warning and the deploy still counts as successful.
- The system journal is capped at 200 MB by `vm/etc/systemd/journald.conf.d/size.conf`.

Check disk use with `df -h /` and `docker system df`.
