#!/bin/sh
set -eu

APP_DIR=/uixb/m365-copilot2api
IMAGE=ghcr.io/bundle5936/m365-copilot2api:latest
PREVIOUS=ghcr.io/bundle5936/m365-copilot2api:previous
CANDIDATE=ghcr.io/bundle5936/m365-copilot2api:candidate
LOCK=/run/m365-copilot2api-image-pull.lock
STATE_DIR=/var/lib/m365-copilot2api
CONTAINER=m365-copilot2api

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another image update is already running"
  exit 0
fi

cd "$APP_DIR"
install -d -m 0755 "$STATE_DIR"
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_DIR/last-pull-at"

running_id="$(docker inspect -f '{{.Image}}' "$CONTAINER" 2>/dev/null || true)"
local_id="$(docker image inspect "$IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
rollback_id="${running_id:-$local_id}"
if [ -n "$rollback_id" ]; then
  docker tag "$rollback_id" "$PREVIOUS"
  printf '%s\n' "$rollback_id" > "$STATE_DIR/previous-image-id"
fi

# The only build happens in GitHub Actions. Oracle only pulls the public GHCR
# image and starts it with --no-build.
docker compose pull --quiet
new_id="$(docker image inspect "$IMAGE" --format '{{.Id}}')"
revision="$(docker image inspect "$IMAGE" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}' 2>/dev/null || true)"

if [ "$running_id" = "$new_id" ]; then
  printf '%s\n' "$new_id" > "$STATE_DIR/production-image-id"
  printf '%s\n' "$revision" > "$STATE_DIR/production-revision"
  echo "image unchanged; production is already running $new_id"
  exit 0
fi

echo "updating production image: ${running_id:-none} -> $new_id (revision=${revision:-unknown})"
docker compose up -d --no-build

wait_healthy() {
  for _ in $(seq 1 45); do
    status="$(docker inspect -f '{{.State.Health.Status}}' "$CONTAINER" 2>/dev/null || true)"
    if [ "$status" = healthy ]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

if wait_healthy; then
  printf '%s\n' "$new_id" > "$STATE_DIR/production-image-id"
  printf '%s\n' "$revision" > "$STATE_DIR/production-revision"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_DIR/deployed-at"
  # candidate was used by the old approval flow; remove only its tag.
  docker image rm "$CANDIDATE" >/dev/null 2>&1 || true
  docker image prune -f >/dev/null 2>&1 || true
  echo "automatic deployment healthy: $new_id"
  exit 0
fi

echo "new image failed health check; rolling back" >&2
if [ -n "$rollback_id" ] && docker image inspect "$PREVIOUS" >/dev/null 2>&1; then
  docker tag "$PREVIOUS" "$IMAGE"
  docker compose up -d --no-build
  if wait_healthy; then
    echo "rollback healthy: $rollback_id" >&2
  else
    echo "rollback did not become healthy" >&2
  fi
fi
exit 1
