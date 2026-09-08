#!/bin/sh
set -eu

APP_DIR=/uixb/m365-copilot2api
IMAGE=ghcr.io/bundle5936/m365-copilot2api:latest
CANDIDATE=ghcr.io/bundle5936/m365-copilot2api:candidate
PREVIOUS=ghcr.io/bundle5936/m365-copilot2api:previous
LOCK=/run/m365-copilot2api-deploy.lock
STATE_DIR=/var/lib/m365-copilot2api

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another deployment is already running"
  exit 0
fi

cd "$APP_DIR"

selected="${1:-candidate}"
case "$selected" in
  candidate)
    ref="$CANDIDATE"
    ;;
  latest)
    ref="$IMAGE"
    ;;
  sha-*)
    ref="ghcr.io/bundle5936/m365-copilot2api:$selected"
    docker pull "$ref"
    ;;
  *)
    echo "usage: $0 [candidate|latest|sha-<short-sha>]" >&2
    exit 2
    ;;
esac

new_id="$(docker image inspect "$ref" --format '{{.Id}}' 2>/dev/null || true)"
if [ -z "$new_id" ]; then
  echo "image not found locally: $ref (run the pull timer first, or use a sha tag)" >&2
  exit 1
fi

old_id="$(docker inspect -f '{{.Image}}' m365-copilot2api 2>/dev/null || true)"
if [ -n "$old_id" ]; then
  docker tag "$old_id" "$PREVIOUS"
fi
# Compose uses the local latest tag with pull_policy=missing. This explicit
# retag is the approval boundary for a candidate or a fixed SHA.
docker tag "$ref" "$IMAGE"
docker compose up -d --no-build

healthy=0
for _ in $(seq 1 45); do
  status="$(docker inspect -f '{{.State.Health.Status}}' m365-copilot2api 2>/dev/null || true)"
  if [ "$status" = healthy ]; then
    healthy=1
    break
  fi
  sleep 2
done

if [ "$healthy" -eq 1 ]; then
  install -d -m 0755 "$STATE_DIR"
  printf '%s\n' "$new_id" > "$STATE_DIR/production-image-id"
  printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_DIR/deployed-at"
  echo "deployment healthy: $new_id"
  exit 0
fi

echo "deployment failed health check; restoring previous image" >&2
if [ -n "$old_id" ] && docker image inspect "$PREVIOUS" >/dev/null 2>&1; then
  docker tag "$PREVIOUS" "$IMAGE"
  docker compose up -d --no-build
fi
exit 1
