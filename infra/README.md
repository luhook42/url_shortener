# infra/

Everything that runs on `shortener-vm` but is not part of the app. These files are copies of what is on the VM. The VM is the source of truth until we add an install script, so if you change a file there, copy it back here.

## Layout

- `bin/deploy.sh` -> `/usr/local/bin/deploy.sh`. The only command the restricted deploy key may run. Takes `deploy <sha>` or `health`.
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
3. Create the two env files described above (root, mode 600).
4. Enable the timers: `sudo systemctl daemon-reload && sudo systemctl enable --now backup-db.timer site-health.timer`
5. Add the deploy public key to `~/.ssh/authorized_keys` with these restrictions in front of it: `command="/usr/local/bin/deploy.sh",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty`
6. Update the `VM_KNOWN_HOSTS` GitHub secret (a new VM has a new host key).

## GCP resources (created by hand for now)

- VM `shortener-vm` (us-central1-a), running as service account `backup-writer` with scope `storage-rw`
- Reserved static IP `shortener-ip`
- Bucket `luhook42-shortener-backups-e985c781` with a 30-day delete lifecycle rule. `backup-writer` has `objectCreator` and `objectViewer` on it.
- Firewall rule `allow-4567-from-my-ip`; port 22 open

These are the resources Terraform will take over later.
