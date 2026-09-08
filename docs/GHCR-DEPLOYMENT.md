# GHCR 自动部署

生产环境只运行 GitHub Actions 已通过测试并发布到 GHCR 的镜像，不在 Oracle 本地执行 Go/Docker 构建。

## 发布链路

1. `CI` 在 `uixb-v0.7.0-enhancements` 的 push 上运行 `go test ./...` 和 Docker build。
2. `Publish container image` 只监听成功的 `CI` `workflow_run`，使用通过测试的 commit 构建 `linux/amd64` 与 `linux/arm64` 镜像。
3. 镜像发布到 `ghcr.io/bundle5936/m365-copilot2api`，保留 `latest` 与 `sha-<短 SHA>` 标签。
4. Oracle 上的 systemd timer 每 5 分钟执行一次 `docker compose pull`；检测到镜像 digest 变化后执行 `docker compose up -d --no-build`。
5. 新容器必须通过健康检查；失败时脚本把本地 `:previous` 镜像重新标记为 `:latest` 并重新启动容器。

## Oracle 安装

Oracle 项目目录固定为 `/uixb/m365-copilot2api`，Compose 使用：

```yaml
image: ghcr.io/bundle5936/m365-copilot2api:latest
pull_policy: always
```

安装本目录中的三个 systemd 文件后：

```bash
install -m 0755 deploy/deploy-m365-copilot2api-pull.sh /usr/local/sbin/m365-copilot2api-pull
install -m 0644 deploy/m365-copilot2api-image-pull.service /etc/systemd/system/
install -m 0644 deploy/m365-copilot2api-image-pull.timer /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now m365-copilot2api-image-pull.timer
```

生产 `.env`、`data/`、管理员密码、API key 与 token 不进入仓库。生产部署仍可通过停止 timer、固定 Compose 镜像为 `sha-<短 SHA>` 进行人工确认或回滚。
