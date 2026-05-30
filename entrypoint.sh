#!/bin/sh
# pi-web 启动入口。
# 关键点：Next.js 用自带的 undici，绕过 Node 的 NODE_USE_ENV_PROXY，
# 导致 pi-web 里的 OAuth token 交换等 fetch 不走代理。受限网络下会触发
# OpenAI 的 unsupported_country_region_territory 403。
# 解决：若配置了代理，则用 proxychains 在 connect() 系统调用层强制所有
# 出站流量走代理（与具体用哪个 fetch 实现无关），否则直接启动。
set -e

PORT="${PORT:-30141}"

# 代理地址来源（按优先级）：PI_PROXY > ALL_PROXY > HTTPS_PROXY
PROXY_URL="${PI_PROXY:-${ALL_PROXY:-${all_proxy:-${HTTPS_PROXY:-${https_proxy:-}}}}}"

if [ -z "$PROXY_URL" ]; then
  echo "[entrypoint] no proxy configured, starting pi-web directly"
  exec pi-web --hostname 0.0.0.0 --port "$PORT"
fi

# 解析 scheme://host:port
scheme=$(printf '%s' "$PROXY_URL" | sed -E 's#^([a-zA-Z0-9]+)://.*#\1#')
hostport=$(printf '%s' "$PROXY_URL" | sed -E 's#^[a-zA-Z0-9]+://##; s#/.*$##; s#.*@##')
host=$(printf '%s' "$hostport" | cut -d: -f1)
port=$(printf '%s' "$hostport" | cut -d: -f2)

case "$scheme" in
  socks5|socks5h) pctype=socks5 ;;
  socks4)         pctype=socks4 ;;
  *)              pctype=http ;;
esac

# proxychains 配置写到 /tmp（root / 非 root 用户都可写）
CONF=/tmp/proxychains.conf
cat > "$CONF" <<EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
# 本机与内网直连，不走代理（含代理服务器自身）
localnet 127.0.0.0/255.0.0.0
localnet 10.0.0.0/255.0.0.0
localnet 172.16.0.0/255.240.0.0
localnet 192.168.0.0/255.255.0.0
[ProxyList]
$pctype $host $port
EOF

echo "[entrypoint] routing egress via proxychains: $pctype $host $port"
exec proxychains4 -q -f "$CONF" pi-web --hostname 0.0.0.0 --port "$PORT"
