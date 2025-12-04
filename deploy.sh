#!/bin/bash
# Home Assistant Docker 一键部署脚本（支持 HomeKit）
# 适用于 macOS

set -e

echo "======================================"
echo "Home Assistant Docker 部署"
echo "支持 HomeKit + 米家"
echo "======================================"
echo ""

# 步骤 1: 检查 Docker
echo "📦 步骤 1/5: 检查 Docker 环境..."
echo ""

if ! command -v docker &> /dev/null; then
    echo "❌ 错误: 未安装 Docker"
    echo ""
    echo "请先安装 Docker Desktop:"
    echo ""
    echo "方法 1: 从官网下载（推荐）"
    echo "  https://www.docker.com/products/docker-desktop"
    echo ""
    echo "方法 2: 使用脚本下载"
    echo "  curl -L -o ~/Downloads/Docker.dmg https://desktop.docker.com/mac/main/arm64/Docker.dmg"
    echo "  open ~/Downloads/Docker.dmg"
    echo ""
    exit 1
fi

if ! docker info &> /dev/null; then
    echo "❌ 错误: Docker 未运行"
    echo ""
    echo "请启动 Docker Desktop 应用"
    exit 1
fi

echo "✓ Docker 已安装并运行"
DOCKER_VERSION=$(docker --version | cut -d ' ' -f3 | cut -d ',' -f1)
echo "  版本: $DOCKER_VERSION"
echo ""

# 步骤 2: 创建目录结构
echo "📁 步骤 2/5: 创建配置目录..."
echo ""

mkdir -p config
mkdir -p avahi

echo "✓ 配置目录已创建"
echo "  - ./config (Home Assistant 配置)"
echo "  - ./avahi (Avahi 配置)"
echo ""

# 步骤 3: 配置 Avahi（HomeKit 支持）
echo "🔧 步骤 3/5: 配置 HomeKit 支持..."
echo ""

cat > avahi/avahi-daemon.conf << 'EOF'
[server]
host-name=homeassistant
domain-name=local
use-ipv4=yes
use-ipv6=no
allow-interfaces=en0
deny-interfaces=docker0
ratelimit-interval-usec=1000000
ratelimit-burst=1000

[wide-area]
enable-wide-area=yes

[publish]
publish-addresses=yes
publish-hinfo=yes
publish-workstation=no
publish-domain=yes

[reflector]
enable-reflector=no

[rlimits]
rlimit-core=0
rlimit-data=4194304
rlimit-fsize=0
rlimit-nofile=768
rlimit-stack=4194304
rlimit-nproc=3
EOF

echo "✓ Avahi 配置完成（支持 HomeKit mDNS）"
echo ""

# 步骤 4: 检查端口占用
echo "🔍 步骤 4/5: 检查端口..."
echo ""

if lsof -Pi :8123 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  警告: 端口 8123 被占用"
    echo ""
    read -p "是否停止占用端口的进程? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        lsof -ti:8123 | xargs kill -9 2>/dev/null || true
        echo "✓ 已停止占用端口的进程"
    else
        echo "请手动停止占用端口的进程后重试"
        exit 1
    fi
fi

echo "✓ 端口 8123 可用"
echo ""

# 步骤 5: 启动服务
echo "🚀 步骤 5/5: 启动 Home Assistant..."
echo ""

# 拉取镜像
echo "  下载 Docker 镜像（首次需要几分钟）..."
docker-compose pull

# 启动服务
echo "  启动容器..."
docker-compose up -d

echo ""
echo "✓ 服务已启动"
echo ""

# 等待服务就绪
echo "⏳ 等待 Home Assistant 启动（约 5-10 分钟）..."
echo ""

MAX_WAIT=600
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "✓ Home Assistant 已就绪！"
        break
    fi
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "  等待中... ($ELAPSED 秒)"
done

echo ""
echo "======================================"
echo "✅ 部署完成！"
echo "======================================"
echo ""
echo "访问地址: http://localhost:8123"
echo ""
echo "管理命令:"
echo "  启动: docker-compose up -d"
echo "  停止: docker-compose down"
echo "  日志: docker-compose logs -f"
echo "  状态: docker-compose ps"
echo ""
echo "配置目录: ./config"
echo "备份脚本: ./scripts/backup-homeassistant.sh"
echo ""
echo "下一步:"
echo "1. 访问 http://localhost:8123"
echo "2. 完成初始设置"
echo "3. 配置 HomeKit 集成（支持 mDNS）"
echo "4. 配置米家集成"
echo ""
echo "验证 HomeKit 配置:"
echo "  ./scripts/verify-homekit.sh"
echo ""
echo "如需从 Core 迁移，运行:"
echo "  ./scripts/restore-homeassistant.sh"
echo ""
