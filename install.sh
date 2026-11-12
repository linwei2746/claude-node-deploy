#!/bin/bash
set -e

echo "=== [1/4] 检查并配置 2GB Swap 虚拟内存 ==="
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "=== [2/4] 检查并安装 Docker ==="
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

echo "=== [3/4] 初始化权限与随机防关联 Hostname ==="
cd "$(dirname "$0")"
mkdir -p claude_config workspace
chown -R 1000:1000 claude_config workspace
chmod 700 claude_config

if [ ! -f .env ]; then
    PREFIXES=("ubuntu-dev" "debian-workstation" "thinkpad-x1" "dev-box" "linux-studio" "arch-pc")
    RANDOM_PREFIX=${PREFIXES[$RANDOM % ${#PREFIXES[@]}]}
    RANDOM_SUFFIX=$(head /dev/urandom | tr -dc 'a-z0-9' | head -c 4)
    RAND_HOSTNAME="${RANDOM_PREFIX}-${RANDOM_SUFFIX}"
    
    echo "NODE_HOSTNAME=${RAND_HOSTNAME}" > .env
    echo "NODE_TZ=America/Los_Angeles" >> .env
    echo "✅ 已生成本机专属随机主机名: ${RAND_HOSTNAME}"
else
    echo "已存在 .env 配置: $(grep NODE_HOSTNAME .env)"
fi

echo "=== [4/4] 启动 Claude 容器 ==="
docker compose up -d --build
echo "🎉 部署完成！当前容器主机名为: $(docker exec claude-worker hostname)"
