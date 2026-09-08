#!/bin/sh
set -eu

APP_DIR=/uixb/m365-copilot2api
IMAGE=ghcr.io/bundle5936/m365-copilot2api:latest
CANDIDATE=ghcr.io/bundle5936/m365-copilot2api:candidate
LOCK=/run/m365-copilot2api-image-pull.lock
STATE_DIR=/var/lib/m365-copilot2api

exec 9>"$LOCK"
if ! flock -n 9; then
  echo "another image pull is already running"
  exit 0
fi

cd "$APP_DIR"
docker compose pull --quiet
candidate_id="$(docker image inspect "$IMAGE" --format '{{.Id}}')"
docker tag "$IMAGE" "$CANDIDATE"
install -d -m 0755 "$STATE_DIR"
printf '%s\n' "$candidate_id" > "$STATE_DIR/candidate-image-id"
printf '%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$STATE_DIR/candidate-pulled-at"

if docker inspect m365-copilot2api >/dev/null 2>&1; then
  running_id="$(docker inspect -f '{{.Image}}' m365-copilot2api)"
else
  running_id=""
fi
if [ "$running_id" = "$candidate_id" ]; then
  echo "candidate is already running: $candidate_id"
else
  echo "candidate ready (not deployed): $candidate_id"
  echo "approve explicitly with: systemctl start m365-copilot2api-deploy.service"
fi
