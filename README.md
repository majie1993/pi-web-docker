# pi-web-docker

把 [`@agegr/pi-web`](https://www.npmjs.com/package/@agegr/pi-web)（pi coding agent 的网页界面）和 [`pi`](https://github.com/badlogic/pi-mono) agent 本身打包进一个 Docker 镜像，开箱即用。

> ⚠️ **安全提醒**：pi 是带 `bash` / `write` / `edit` 权限的 coding agent。把网页界面暴露给谁，谁就能在容器里跑任意命令。本镜像默认只绑定到宿主机 `127.0.0.1`，**不要无鉴权地暴露到公网**。

## 快速开始

```bash
docker compose up -d
```

打开 http://localhost:30141 。首次进入后在侧边栏 **Models** 面板里填好模型和 API key —— 这些会写进挂载的 `./data` 目录持久化，不会进镜像、不会进 git。

或者不用 compose，直接 run：

```bash
docker run -d --name pi-web \
  -p 127.0.0.1:30141:30141 \
  -v "$PWD/data:/data" \
  ghcr.io/<your-github-name>/pi-web-docker:latest
```

## 远程访问

镜像只绑定本地回环，公网访问不到。需要远程用时走隧道，不要直接开端口：

```bash
# Tailscale：装好后用 MagicDNS 访问
# 或 cloudflared 临时隧道：
cloudflared tunnel --url http://localhost:30141
```

## 数据与密钥

| 路径 | 说明 |
| --- | --- |
| `./data/.pi/agent/sessions` | 会话记录（`.jsonl`） |
| `./data/.pi/agent/models.json` | 模型列表与 API key |

`data/` 已在 `.gitignore` 中，**永远不会被提交**。

## 本地构建

```bash
docker build -t pi-web-docker .
```

## 自动构建

push 到 `main` 或打 `v*` tag 后，GitHub Actions 自动构建并推送到 `ghcr.io/<owner>/pi-web-docker`（见 `.github/workflows/docker.yml`）。镜像默认为 private，可在仓库 **Packages** 设置里改为 public。
