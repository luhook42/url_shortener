#!/usr/bin/env bash
# Run ON YOUR MAC. Copies infra/vm/ to the VM and compares or installs it.
# Usage: infra/bin/sync-vm.sh check   (show differences, change nothing)
#        infra/bin/sync-vm.sh apply   (back up and install changed files)
set -euo pipefail
MODE="${1:-check}"
[[ "$MODE" == check || "$MODE" == apply ]] || { echo "usage: $0 check|apply" >&2; exit 2; }
VM="luhook42@shortener-vm"; ZONE="us-central1-a"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C "$ROOT/infra" -czf "$TMP/vm.tgz" vm bin/vm-apply.sh
gcloud compute scp --zone "$ZONE" "$TMP/vm.tgz" "$VM:/tmp/vm-sync.tgz" >/dev/null
gcloud compute ssh "$VM" --zone "$ZONE" --command "set -e; d=\$(mktemp -d); tar -xzf /tmp/vm-sync.tgz -C \$d; rm -f /tmp/vm-sync.tgz; sudo bash \$d/bin/vm-apply.sh $MODE \$d/vm; rm -rf \$d"
