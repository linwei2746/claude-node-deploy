FROM node:20-bookworm-slim

# 安装基础工具与 git
RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates procps \
    && rm -rf /var/lib/apt/lists/*

# 安装官方 Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

# 将默认 node 用户 (UID 1000) 作为日常运行用户，避免 root 特征
USER node
WORKDIR /home/node

# 固定配置目录并关闭非必要遥测，节省内存与流量
ENV HOME=/home/node
ENV CLAUDE_CONFIG_DIR=/home/node/.claude
ENV CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
# 限制 Node.js 最大堆内存为 512M，防止撑爆 1G 内存 VPS
ENV NODE_OPTIONS="--max-old-space-size=512"

CMD ["sleep", "infinity"]
