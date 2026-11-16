#!/usr/bin/env bash
# Runs daily ON THE VM as root (vm-drift-check.timer). Compares the installed
# server files with infra/vm in the deployed checkout and pings the monitor,
# or its /fail URL with the names of the files that differ.
set -uo pipefail
source /etc/vm-drift.env
REPO=/home/luhook42/url_shortener

# The checkout is user-writable, so it is only read as data: the comparison
# runs the root-owned copy of vm-apply.sh, never a script from the checkout.
out="$(/usr/local/bin/vm-apply.sh check "$REPO/infra/vm" 2>&1)"; rc=$?

if [[ $rc -eq 0 ]]; then
  curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL"
  exit 0
fi

# File names only, never the diffs: they include live /etc files, which may
# hold secrets, and this goes to an outside service.
if [[ $rc -eq 1 ]]; then
  body="Server files differ from the repo. Run infra/bin/sync-vm.sh check:"$'\n'"$(grep '^=== ' <<<"$out" | sed 's/^=== /  /')"
else
  body="Drift check failed to run (vm-apply.sh exited $rc)."
fi
curl -fsS -m 10 --retry 3 -o /dev/null --data-binary "$body" "$HC_URL/fail"
exit 1
