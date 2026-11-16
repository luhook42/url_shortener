#!/usr/bin/env bash
# Run ON YOUR MAC. Copies infra/vm/ to the VM and compares or installs it.
# Usage: infra/bin/sync-vm.sh check   (show differences, change nothing)
#        infra/bin/sync-vm.sh apply   (back up and install changed files)
set -euo pipefail
MODE="${1:-check}"
[[ "$MODE" == check || "$MODE" == apply ]] || { echo "usage: $0 check|apply" >&2; exit 2; }
VM="luhook42@shortener-vm"; ZONE="us-central1-a"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# apply installs whatever is in this working copy, so only allow it from a
# clean main that matches GitHub: what lands on the VM is then what was merged.
if [[ "$MODE" == apply ]]; then
  refuse() { echo "refusing to apply: $1" >&2; exit 1; }
  branch="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD || echo 'a detached HEAD')"
  [[ "$branch" == main ]] || refuse "you're on $branch, not main"
  # --ignored too: tar ships ignored files (e.g. .DS_Store) as well.
  dirty="$(git -C "$ROOT" status --porcelain --untracked-files=all --ignored -- infra/vm)"
  [[ -z "$dirty" ]] || refuse "infra/vm has uncommitted, untracked or ignored files:"$'\n'"$dirty"
  git -C "$ROOT" fetch --quiet origin main || refuse "couldn't fetch origin/main to check you're up to date"
  [[ "$(git -C "$ROOT" rev-parse HEAD)" == "$(git -C "$ROOT" rev-parse origin/main)" ]] \
    || refuse "local main doesn't match origin/main (pull or push first)"
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
COPYFILE_DISABLE=1 tar --no-xattrs --no-mac-metadata -C "$ROOT/infra" -czf "$TMP/vm.tgz" vm
gcloud compute scp --zone "$ZONE" "$TMP/vm.tgz" "$VM:/tmp/vm-sync.tgz" >/dev/null
gcloud compute ssh "$VM" --zone "$ZONE" --command "set -e; d=\$(mktemp -d); tar -xzf /tmp/vm-sync.tgz -C \$d; rm -f /tmp/vm-sync.tgz; rc=0; sudo bash \$d/vm/usr/local/bin/vm-apply.sh $MODE \$d/vm || rc=\$?; rm -rf \$d; exit \$rc"
