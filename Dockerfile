# pi-web + pi coding agent 一体化镜像
# pi 要求 Node >= 22.19；选 24 是因为它才内置了 NODE_USE_ENV_PROXY，
# 能让原生 fetch 读 HTTP(S)_PROXY 环境变量（pi 自身完全不处理代理）
FROM node:24-bookworm-slim

# pi agent 需要 git 等基础工具来操作工作区；ripgrep 供其搜索能力使用
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        ripgrep \
        proxychains-ng \
    && rm -rf /var/lib/apt/lists/*

# 显式锁定公共 npm 源，避免在内网环境构建时误继承私有 .npmrc
RUN npm config set registry https://registry.npmjs.org/

# 全局安装网页界面 (@agegr/pi-web，提供 pi-web 命令)
# 与底层 coding agent (@earendil-works/pi-coding-agent，提供 pi 命令)
# 安装版本由构建参数控制：默认 latest，CI 会传入解析好的具体版本号，
# 这样上游发新版时 arg 变化会让本层缓存失效，从而真正重装新版
ARG PI_WEB_VERSION=latest
ARG PI_AGENT_VERSION=latest
RUN npm install -g \
        @agegr/pi-web@${PI_WEB_VERSION} \
        @earendil-works/pi-coding-agent@${PI_AGENT_VERSION} \
    && npm cache clean --force

# pi-web 启动就绪后会 spawn `xdg-open` 自动打开浏览器，且未对该子进程挂 error 处理。
# 容器内没有 xdg-open 时 spawn 报 ENOENT，会触发未捕获异常使进程崩溃重启。
# 放一个 no-op 的 xdg-open 占位，让 spawn 成功但不做任何事。
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xdg-open \
    && chmod +x /usr/local/bin/xdg-open

# 把 HOME 指到 /data，这样 pi / pi-web 默认读写的 ~/.pi 会落在 /data/.pi
# 会话记录、models.json、API key 都存在这里，通过 volume 持久化
ENV HOME=/data
RUN mkdir -p /data && chmod 777 /data
VOLUME ["/data"]

# 让 Node 原生 fetch 识别 HTTP_PROXY/HTTPS_PROXY/NO_PROXY 环境变量。
# pi 用裸 fetch 调 OpenAI/Anthropic，自身不处理代理；不设此项时代理会被无视，
# 在受限地区会触发 OpenAI 的 unsupported_country_region_territory 403。
# 未配置代理环境变量时此开关无副作用。
ENV NODE_USE_ENV_PROXY=1

# 容器内监听所有网卡，真正的对外暴露范围由 docker run -p 控制
ENV PORT=30141
EXPOSE 30141

# 入口脚本：按需用 proxychains 包住 pi-web，强制出站走代理
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# agent 默认操作的工作目录
WORKDIR /workspace

# 监听 0.0.0.0 是为了让宿主机 -p 端口映射可达；
# 安全边界在宿主侧（绑定 127.0.0.1 + 隧道），不在容器内
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
