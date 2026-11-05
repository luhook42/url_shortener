#!/usr/bin/env bash
# Runs ON THE VM as root (called by sync-vm.sh). Compares every file under SRC
# with the live file at the same path. check = show differences only; apply = back up and install.
set -euo pipefail
MODE="$1"; SRC="$2"
BACKUP="/var/backups/vm-config/$(date -u +%Y%m%dT%H%M%SZ)"
changed=0; reload_systemd=0; restart=()
while IFS= read -r -d '' f; do
  rel="${f#"$SRC"}"
  # Ignore macOS metadata files and anything outside the two allowed places.
  if [[ "${rel##*/}" == ._* ]]; then continue; fi
  case "$rel" in
    /usr/local/bin/*|/etc/*) ;;
    *) echo "skipped $rel (only /etc and /usr/local/bin are allowed)"; continue ;;
  esac
  case "$rel" in */bin/*) mode=755 ;; *) mode=644 ;; esac
  if [[ -f "$rel" ]] && cmp -s "$f" "$rel"; then continue; fi
  changed=$((changed + 1))
  echo "=== $rel"
  if [[ -f "$rel" ]]; then diff -u "$rel" "$f" || true; else echo "(new file)"; fi
  [[ "$MODE" == apply ]] || continue
  if [[ -f "$rel" ]]; then install -D -m 600 "$rel" "$BACKUP$rel"; fi
  install -D -m "$mode" -o root -g root "$f" "$rel"
  case "$rel" in
    /etc/systemd/system/*) reload_systemd=1 ;;
    /etc/systemd/journald.conf.d/*) restart+=(systemd-journald) ;;
    /etc/google-cloud-ops-agent/*) restart+=(google-cloud-ops-agent) ;;
  esac
done < <(find "$SRC" -type f -print0 | sort -z)

if [[ "$MODE" == check ]]; then
  echo
  if [[ $changed -eq 0 ]]; then echo "VM matches the repo."; else echo "$changed file(s) differ from the repo. Nothing was changed."; fi
  exit 0
fi
if [[ $reload_systemd -eq 1 ]]; then systemctl daemon-reload; echo "reloaded systemd"; fi
for s in $(printf '%s\n' "${restart[@]:-}" | sort -u); do
  systemctl restart "$s"
  echo "restarted $s: $(systemctl is-active "$s")"
done
if [[ $changed -gt 0 ]]; then echo "$changed file(s) installed. Old copies saved in $BACKUP"; else echo "Nothing to install."; fi
