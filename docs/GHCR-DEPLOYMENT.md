# GHCR 与 Oracle Watchtower 自动更新

Oracle 不保留 Go 源码，也不执行本地 Go/Docker build。GitHub Actions 负责测试和构建镜像；Oracle 使用现有的 Watchtower Docker 容器自动拉取并更新 M365-Copilot2API。

## 自动链路

1. `Sync upstream release` 每 30 分钟检查上游 Release。
2. 无冲突时临时合并上游，执行 `go test ./...` 和 Docker build。
3. 测试通过后提交到 `uixb-v0.7.0-enhancements`。
4. `CI` 成功后，`Publish container image` 发布：
   - `ghcr.io/bundle5936/m365-copilot2api:latest`
   - `ghcr.io/bundle5936/m365-copilot2api:sha-<短 SHA>`
5. Oracle 的 Watchtower 每小时检查所有容器，`m365-copilot2api` 不在排除列表中，因此会自动拉取新的 GHCR `latest` 并重建容器。

Oracle 不执行源码构建。正常发布不发送 Telegram 通知；合并冲突、测试失败、CI 失败或镜像发布失败由 n8n Problem Monitor 通知并附带 LXC Pi 审查入口。

## Oracle Compose

`/uixb/m365-copilot2api/docker-compose.yml` 只使用：

```yaml
image: ghcr.io/bundle5936/m365-copilot2api:latest
pull_policy: missing
```

没有 `build:`。`pull_policy: missing` 不影响 Watchtower：Watchtower 会先自行拉取新镜像，再按当前容器配置重建服务。

## Watchtower

Watchtower 配置位于 Oracle：

```text
/uixb/watch/docker-compose.yml
```

关键配置：

```yaml
environment:
  - WATCHTOWER_CLEANUP=true
  - WATCHTOWER_POLL_INTERVAL=3600
  - WATCHTOWER_DISABLE_CONTAINERS=chromium
```

`m365-copilot2api` 不在 `WATCHTOWER_DISABLE_CONTAINERS` 中，因此由 Watchtower 自动更新。查看状态：

```bash
docker ps --filter name=watchtower
docker logs --since 2h watchtower
docker inspect m365-copilot2api
```

## Oracle 运行目录

`/uixb/m365-copilot2api` 只保留：

- `docker-compose.yml`
- `.env`
- `data/`
- `AGENTS.md` 与保留的 `agent.md` 链接

不保留 Go 源码、`.git`、Dockerfile、测试目录或 GitHub Actions 文件。生产账号、API key、管理员密码和 usage 数据仍只保存在 Oracle 的 `.env` 与 `data/` 中。
