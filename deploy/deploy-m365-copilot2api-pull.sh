#!/bin/sh
set -eu

APP_DIR=/uixb/m365-copilot2api
IMAGE=ghcr.io/bundle5936/m365-copilot2api:latest
LOCK=/run/m365-copilot2api-image-pull.lock

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another image pull is already running"
  exit 0
fi

cd "$APP_DIR"

old_id="$(docker image inspect "$IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
if [ -n "$old_id" ]; then
  docker tag "$IMAGE" ghcr.io/bundle5936/m365-copilot2api:previous
fi

docker compose pull --quiet
new_id="$(docker image inspect "$IMAGE" --format '{{.Id}}')"

if [ "$old_id" = "$new_id" ]; then
  echo "image unchanged: $new_id"
  exit 0
fi

echo "new image detected: ${old_id:-none} -> $new_id"
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
  echo "deployment healthy: $new_id"
  exit 0
fi

echo "deployment failed health check; restoring previous image" >&2
if [ -n "$old_id" ] && docker image inspect ghcr.io/bundle5936/m365-copilot2api:previous >/dev/null 2>&1; then
  docker tag ghcr.io/bundle5936/m365-copilot2api:previous "$IMAGE"
  docker compose up -d --no-build
fi
exit 1
