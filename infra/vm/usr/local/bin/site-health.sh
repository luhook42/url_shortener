#!/usr/bin/env bash
set -uo pipefail
source /etc/site-health.env
if curl -fsS -m 5 -o /dev/null http://localhost:4567/health; then
  curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL"
else
  curl -fsS -m 10 --retry 3 -o /dev/null "$HC_URL/fail"
fi
