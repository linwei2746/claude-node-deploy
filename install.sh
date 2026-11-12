#!/bin/bash
set -e

echo "=== [1/5] 配置 SSH 密钥免密登录并关闭密码爆破入口 ==="
PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEnF5zMmUV4mKRXn8TuhhCtsOZkjo3L9KHBMWU1ARJ0p linwe@DESKTOP-V4QT3UK"

mkdir -p /root/.ssh
chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

if ! grep -qF "$PUBKEY" /root/.ssh/authorized_keys; then
    echo "$PUBKEY" >> /root/.ssh/authorized_keys
    echo "✅ 已写入管理机 SSH 公钥"
else
    echo "SSH 公钥已存在，跳过写入"
fi

# 确认公钥已成功写入后，关闭 SSH 密码登录（兼容 Ubuntu 20.04/22.04/24.04 cloud-init 配置）
if grep -qF "AAAAC3NzaC1lZDI1NTE5AAAAIEnF5zMmUV4mKRXn8TuhhCtsOZkjo3L9KHBMWU1ARJ0p" /root/.ssh/authorized_keys; then
    sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/g' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/g' /etc/ssh/sshd_config
    if [ -d /etc/ssh/sshd_config.d ]; then
        sed -i 's/^PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true
    fi
    if sshd -t 2>/dev/null; then
        systemctl reload ssh 2>/dev/null || systemctl reload sshd 2>/dev/null || true
        echo "🔒 已开启 SSH 密钥登录并彻底关闭密码登录（防暴力破解已生效）"
    fi
fi

echo "=== [2/5] 检查并配置 2GB Swap 虚拟内存 ==="
if [ ! -f /swapfile ]; then
    fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "=== [3/5] 检查并安装 Docker ==="
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
fi

echo "=== [4/5] 初始化权限与随机防关联 Hostname ==="
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

echo "=== [5/5] 启动 Claude 容器并配置宿主机 claude 快捷命令 ==="
docker compose up -d --build

# 创建全局 /usr/local/bin/claude 转发脚本（无需重登终端即可直接在宿主机敲 claude 使用，且支持带参数调用）
cat << 'WRAPPER' > /usr/local/bin/claude
#!/bin/bash
if [ -t 0 ] && [ -t 1 ]; then
    exec docker exec -it claude-worker claude "$@"
else
    exec docker exec -i claude-worker claude "$@"
fi
WRAPPER
chmod +x /usr/local/bin/claude

if ! grep -q "alias claude=" ~/.bashrc 2>/dev/null; then
    echo "alias claude='docker exec -it claude-worker claude'" >> ~/.bashrc
fi

echo "🎉 部署完成！当前容器主机名为: $(docker exec claude-worker hostname)"
echo "💡 现在直接在终端输入 claude 即可进入容器使用！"
