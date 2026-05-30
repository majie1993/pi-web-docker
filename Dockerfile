# pi-web + pi coding agent 一体化镜像
# pi 要求 Node >= 22.19，使用 22 系列 slim 基础镜像
FROM node:22-bookworm-slim

# pi agent 需要 git 等基础工具来操作工作区；ripgrep 供其搜索能力使用
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        ca-certificates \
        ripgrep \
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

# 把 HOME 指到 /data，这样 pi / pi-web 默认读写的 ~/.pi 会落在 /data/.pi
# 会话记录、models.json、API key 都存在这里，通过 volume 持久化
ENV HOME=/data
RUN mkdir -p /data && chmod 777 /data
VOLUME ["/data"]

# 容器内监听所有网卡，真正的对外暴露范围由 docker run -p 控制
ENV PORT=30141
EXPOSE 30141

# agent 默认操作的工作目录
WORKDIR /workspace

# 监听 0.0.0.0 是为了让宿主机 -p 端口映射可达；
# 安全边界在宿主侧（绑定 127.0.0.1 + 隧道），不在容器内
CMD ["pi-web", "--hostname", "0.0.0.0", "--port", "30141"]
