# pi-web-docker

把 [`@agegr/pi-web`](https://www.npmjs.com/package/@agegr/pi-web)（pi coding agent 的网页界面）和 [`pi`](https://github.com/badlogic/pi-mono) agent 本身打包进一个 Docker 镜像，开箱即用。

镜像地址：`ghcr.io/majie1993/pi-web-docker:latest`

> ⚠️ **安全提醒**：pi 是带 `bash` / `write` / `edit` 权限的 coding agent。把网页界面暴露给谁，谁就能在容器里跑任意命令。本镜像默认只绑定到宿主机 `127.0.0.1`，**不要无鉴权地暴露到公网**。

## 快速开始

直接用现成镜像跑：

```bash
docker run -d --name pi-web \
  -p 127.0.0.1:30141:30141 \
  -v "$PWD/data:/data" \
  ghcr.io/majie1993/pi-web-docker:latest
```

或用本仓库的 compose（已配好端口绑定与数据卷）：

```bash
docker compose up -d
```

打开 http://localhost:30141 。首次进入后在侧边栏 **Models** 面板里填好模型和 API key —— 这些会写进挂载的 `./data` 目录持久化，不会进镜像、不会进 git。

## 远程访问

镜像只绑定本地回环，公网访问不到。需要远程用时走隧道，不要直接开端口：

```bash
# Tailscale：装好后用 MagicDNS 访问
# 或 cloudflared 临时隧道：
cloudflared tunnel --url http://localhost:30141
```

## 通过代理访问（受限网络）

在中国大陆等受限网络，OpenAI / Anthropic 会按出口 IP 拦截。本镜像支持配置代理，会用 `proxychains` 在系统调用层强制**所有**出站流量走代理——这能绕过 Next.js 自带 undici 不读 `HTTP_PROXY` 环境变量的坑（否则 pi-web 的 OAuth 登录会报 `unsupported_country_region_territory`）。

在 compose 的 `environment` 里设置代理地址即可（支持 `http` / `socks5`）：

```yaml
    environment:
      PI_PROXY: "http://192.168.x.x:1082"     # 或 socks5://...
```

> 代理的**落地地区必须是服务商支持的**（如美 / 日 / 新；⚠️ 香港、中国大陆 OpenAI 均不支持）。未设置代理时镜像直接启动，不受影响。

## 数据与密钥

| 路径 | 说明 |
| --- | --- |
| `./data/.pi/agent/sessions` | 会话记录（`.jsonl`） |
| `./data/.pi/agent/models.json` | 模型列表与 API key |

`data/` 已在 `.gitignore` 中，**永远不会被提交**。镜像本身不含任何密钥，密钥只在运行时通过挂载的 `./data` 注入。

## 本地构建

```bash
docker build -t pi-web-docker .
```

## 自动构建

push 到 `main` 或打 `v*` tag 后，GitHub Actions 自动构建并推送到 `ghcr.io/majie1993/pi-web-docker`（见 `.github/workflows/docker.yml`）。
