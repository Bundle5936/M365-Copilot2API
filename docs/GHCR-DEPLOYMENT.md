# Container Deployment & Automated Updates

This repository publishes container images to GitHub Container Registry (GHCR) upon testing and verification. Hosts running Docker can pull prebuilt multi-arch images directly without local source compilation.

## Automated Pipeline

1. `Sync upstream release` checks upstream releases periodically.
2. When clean, upstream releases are merged in a clean runner and verified with `go test ./...` and Docker build.
3. Upon passing tests, the maintained branch is updated.
4. `CI` verifies the commit and `Publish container image` pushes to:
   - `ghcr.io/bundle5936/m365-copilot2api:latest`
   - `ghcr.io/bundle5936/m365-copilot2api:sha-<short-sha>`
5. Docker hosts using Watchtower or similar image updaters will automatically pull the updated `latest` tag and recreate the container.

## Compose Configuration Example

```yaml
services:
  app:
    image: ghcr.io/bundle5936/m365-copilot2api:latest
    container_name: m365-copilot2api
    restart: unless-stopped
    pull_policy: missing
    ports:
      - "8080:8080"
    env_file:
      - .env
    volumes:
      - ./data:/app/data
```

## Watchtower Integration Example

To automatically update containers when new images are published:

```yaml
services:
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=3600
```
