#!/usr/bin/env bash
set -euo pipefail
cd /home/luhook42/url_shortener
read -r action arg extra <<<"${SSH_ORIGINAL_COMMAND:-}" || true
case "$action" in
  deploy)
    [[ -z "${extra:-}" && "${arg:-}" =~ ^[0-9a-f]{7,40}$ ]] || { echo "invalid sha" >&2; exit 2; }
    git fetch origin
    git checkout --detach "$arg"
    sha=$(git rev-parse HEAD)
    sudo env WEB_TAG="$sha" docker compose pull web
    sudo env WEB_TAG="$sha" docker compose up -d --no-build
    ;;
  health)
    for i in $(seq 1 15); do
      curl -fsS http://localhost:4567/health && exit 0
      sleep 2
    done
    exit 1
    ;;
  *)
    echo "unknown action" >&2
    exit 2
    ;;
esac
