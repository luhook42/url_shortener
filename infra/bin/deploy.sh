#!/usr/bin/env bash
set -euo pipefail
cd /home/luhook42/url_shortener
read -r action arg extra <<<"${SSH_ORIGINAL_COMMAND:-}" || true
case "$action" in
  deploy)
    [[ -z "${extra:-}" && "${arg:-}" =~ ^[0-9a-f]{7,40}$ ]] || { echo "invalid sha" >&2; exit 2; }
    git fetch origin || echo "git fetch failed, using commits already on the VM" >&2
    sha=$(git rev-parse "$arg^{commit}")
    sudo env WEB_TAG="$sha" docker compose pull web
    git checkout --detach "$sha"
    sudo env WEB_TAG="$sha" docker compose run --rm -T web bundle exec rake db:migrate
    sudo env WEB_TAG="$sha" docker compose up -d --no-build
    sudo docker image prune -af --filter "until=72h" || echo "image cleanup failed" >&2
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