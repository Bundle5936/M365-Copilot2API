# GHCR 自动拉取与人工部署

生产环境只运行 GitHub Actions 已通过测试并发布到 GHCR 的镜像，不在 Oracle 本地执行 Go/Docker 构建。

## 发布链路

1. `CI` 在 `uixb-v0.7.0-enhancements` 的 push 上运行 `go test ./...` 和 Docker build。
2. `Publish container image` 只监听成功的 `CI` `workflow_run`，使用通过测试的 commit 构建 `linux/amd64` 与 `linux/arm64` 镜像。
3. 镜像发布到 `ghcr.io/bundle5936/m365-copilot2api`，保留 `latest` 与 `sha-<短 SHA>` 标签。
4. Oracle 上的 systemd timer 每 5 分钟执行一次 `docker compose pull`，并把新镜像标记为本地 `:candidate`；**只拉取，不重建生产容器**。
5. 生产部署必须由用户明确批准，执行 `systemctl start m365-copilot2api-deploy.service`。部署脚本等待健康检查；失败时恢复本地 `:previous` 镜像。

这样 n8n、GitHub Actions 或 AI 即使发现新镜像，也不会无条件覆盖生产容器。

## Oracle 安装

Oracle 项目目录固定为 `/uixb/m365-copilot2api`，Compose 使用：

```yaml
image: ${M365_IMAGE:-ghcr.io/bundle5936/m365-copilot2api:latest}
pull_policy: missing
```

安装本目录中的脚本和 systemd 文件后：

```bash
install -m 0755 deploy/deploy-m365-copilot2api-pull.sh /usr/local/sbin/m365-copilot2api-pull
install -m 0755 deploy/deploy-m365-copilot2api-deploy.sh /usr/local/sbin/m365-copilot2api-deploy
install -m 0644 deploy/m365-copilot2api-image-pull.service /etc/systemd/system/
install -m 0644 deploy/m365-copilot2api-image-pull.timer /etc/systemd/system/
install -m 0644 deploy/m365-copilot2api-deploy.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now m365-copilot2api-image-pull.timer
```

查看候选版本：

```bash
cat /var/lib/m365-copilot2api/candidate-image-id
journalctl -u m365-copilot2api-image-pull.service -n 30 --no-pager
```

人工确认后部署最新候选：

```bash
systemctl start m365-copilot2api-deploy.service
```

也可以精确部署固定 SHA 标签：

```bash
/usr/local/sbin/m365-copilot2api-deploy sha-<短 SHA>
```

回滚时使用已经保留的本地镜像：

```bash
docker tag ghcr.io/bundle5936/m365-copilot2api:previous ghcr.io/bundle5936/m365-copilot2api:latest
systemctl restart m365-copilot2api
```

生产 `.env`、`data/`、管理员密码、API key 与 token 不进入仓库。
