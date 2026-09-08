# GHCR 自动更新部署

Oracle 生产机不再保留 Go 源码，也不执行本地 Go/Docker build。GitHub Actions 负责测试和构建多架构镜像；Oracle 只从公开 GHCR 拉取并自动更新容器。

## 自动链路

1. `Sync upstream release` 每 30 分钟检查上游 Release。
2. 无冲突时临时合并上游，执行 `go test ./...` 和 Docker build。
3. 测试通过后提交到 `uixb-v0.7.0-enhancements`。
4. `CI` 成功后，`Publish container image` 发布：
   - `ghcr.io/bundle5936/m365-copilot2api:latest`
   - `ghcr.io/bundle5936/m365-copilot2api:sha-<短 SHA>`
5. Oracle systemd timer 每 5 分钟运行一次：
   - `docker compose pull`
   - 如果镜像 digest/ID 变化，执行 `docker compose up -d --no-build`
   - 等待容器健康检查
   - 健康检查失败时自动回滚到本地 `:previous` 镜像

正常情况下不发送 Telegram 通知。GitHub Actions 的合并冲突、测试失败、构建失败、CI 失败和镜像发布失败由 n8n Problem Monitor 通知，并附带 LXC Pi 审查 Deep Link。

## Oracle 运行目录

`/uixb/m365-copilot2api` 只保留：

- `docker-compose.yml`
- `.env`
- `data/`
- `AGENTS.md` 与保留的 `agent.md` 链接

不保留 Go 源码、`.git`、Dockerfile、测试目录或 GitHub Actions 文件。

## systemd

```bash
systemctl status m365-copilot2api-image-pull.timer
journalctl -u m365-copilot2api-image-pull.service -n 50 --no-pager
```

生产状态记录在：

```text
/var/lib/m365-copilot2api/production-image-id
/var/lib/m365-copilot2api/production-revision
/var/lib/m365-copilot2api/deployed-at
```

更新脚本位于：

```text
/usr/local/sbin/m365-copilot2api-pull
```

脚本明确使用 `docker compose up -d --no-build`；Oracle 永远不从源码构建。
