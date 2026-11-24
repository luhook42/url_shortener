#!/usr/bin/env bash
set -euo pipefail
cd /home/luhook42/url_shortener
read -r action arg extra <<<"${SSH_ORIGINAL_COMMAND:-}" || true
case "$action" in
  deploy)
    [[ -z "${extra:-}" && "${arg:-}" =~ ^[0-9a-f]{7,40}$ ]] || { echo "invalid sha" >&2; exit 2; }
    # --prune drops stale remote refs (e.g. a deleted "dependabot" branch) that
    # would otherwise block fetching new ones nested under the same name.
    git fetch --prune origin || echo "git fetch failed, using commits already on the VM" >&2
    sha=$(git rev-parse "$arg^{commit}")
    previous=$(git rev-parse HEAD)
    # Migrate from the new image before touching the working tree, so a failed
    # migration leaves the checkout matching the containers that are running.
    # Pull and migrate with the new commit's docker-compose.yml, though: the
    # checked-out one may lack env vars the new code needs (e.g. SESSION_SECRET).
    compose_next=$(mktemp)
    trap 'rm -f "$compose_next"' EXIT
    git show "$sha:docker-compose.yml" > "$compose_next"
    next=(sudo env WEB_TAG="$sha" docker compose -f "$compose_next" --project-directory . -p url_shortener)
    "${next[@]}" pull web
    "${next[@]}" run --rm -T web bundle exec rake db:migrate
    git checkout --detach "$sha"
    sudo env WEB_TAG="$sha" docker compose up -d --no-build
    # Caddyfile is a single-file bind mount. git checkout replaces the file, so
    # the running container keeps the old copy until it is recreated.
    if ! git diff --quiet "$previous" "$sha" -- Caddyfile; then
      sudo env WEB_TAG="$sha" docker compose up -d --no-build --force-recreate caddy
    fi
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