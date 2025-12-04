#!/bin/bash

# HomeKit 配置验证脚本
# 用于检查 HomeKit Bridge 是否可以被 iPhone 发现

set -e

echo "🔍 HomeKit 配置验证"
echo "===================="
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 检查函数
check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# 1. 检查容器状态
echo "1️⃣  检查容器状态..."
if docker ps | grep -q homeassistant; then
    check_pass "HomeAssistant 容器正在运行"
else
    check_fail "HomeAssistant 容器未运行"
    echo "   请运行: docker-compose up -d"
    exit 1
fi

if docker ps | grep -q avahi; then
    check_pass "Avahi 容器正在运行"
else
    check_warn "Avahi 容器未运行（可选，但推荐）"
fi

echo ""

# 2. 检查网络模式
echo "2️⃣  检查网络模式..."
NETWORK_MODE=$(docker inspect homeassistant --format='{{.HostConfig.NetworkMode}}')
if [ "$NETWORK_MODE" = "host" ]; then
    check_pass "HomeAssistant 使用 host 网络模式"
else
    check_fail "HomeAssistant 未使用 host 网络模式（当前: $NETWORK_MODE）"
    echo "   这是 HomeKit 无法被发现的主要原因！"
    echo "   请修改 docker-compose.yml，添加: network_mode: host"
    echo "   然后运行: docker-compose down && docker-compose up -d"
    exit 1
fi

echo ""

# 3. 检查 HomeAssistant 是否可访问
echo "3️⃣  检查 HomeAssistant 访问..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:8123 | grep -q "200\|302"; then
    check_pass "HomeAssistant Web 界面可访问 (http://localhost:8123)"
else
    check_fail "HomeAssistant Web 界面无法访问"
    echo "   请等待 2-3 分钟让服务完全启动"
    echo "   或查看日志: docker-compose logs -f homeassistant"
    exit 1
fi

echo ""

# 4. 检查 HomeKit 配置
echo "4️⃣  检查 HomeKit 配置..."
if [ -f "config/configuration.yaml" ]; then
    if grep -q "^homekit:" config/configuration.yaml; then
        check_pass "HomeKit 配置已添加到 configuration.yaml"
    else
        check_warn "configuration.yaml 中未找到 homekit 配置"
        echo "   请在 Web 界面中添加 HomeKit 集成"
        echo "   或在 configuration.yaml 中添加 homekit 配置"
    fi
else
    check_warn "找不到 configuration.yaml 文件"
fi

echo ""

# 5. 检查 HomeKit 存储文件
echo "5️⃣  检查 HomeKit 初始化..."
if ls config/.storage/homekit.* 1> /dev/null 2>&1; then
    check_pass "HomeKit 已初始化（找到存储文件）"
    
    # 显示配对码提示
    echo ""
    echo "   💡 提示：配对码可以在以下位置找到："
    echo "   1. Home Assistant Web 界面 > 设置 > 设备与服务 > HomeKit Bridge"
    echo "   2. 容器日志: docker-compose logs homeassistant | grep -i 'setup pin'"
else
    check_warn "HomeKit 尚未初始化"
    echo "   请在 Home Assistant 中添加 HomeKit 集成"
fi

echo ""

# 6. 检查 mDNS 广播
echo "6️⃣  检查 mDNS 广播..."
if command -v dns-sd &> /dev/null; then
    echo "   正在扫描 HomeKit 设备（5 秒）..."
    
    # 使用 timeout 限制扫描时间
    if timeout 5 dns-sd -B _hap._tcp 2>/dev/null | grep -q "Home Assistant"; then
        check_pass "检测到 HomeKit Bridge 的 mDNS 广播"
        echo "   iPhone 应该能够发现此设备"
    else
        check_warn "未检测到 HomeKit Bridge 的 mDNS 广播"
        echo "   可能原因："
        echo "   - HomeKit 尚未完全启动（等待 2-3 分钟）"
        echo "   - HomeKit 集成未配置"
        echo "   - 需要重启容器"
    fi
else
    check_warn "dns-sd 命令不可用，跳过 mDNS 检查"
    echo "   这是 macOS 自带工具，通常应该可用"
fi

echo ""

# 7. 检查防火墙
echo "7️⃣  检查防火墙状态..."
FIREWALL_STATE=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate 2>/dev/null | grep -o "enabled\|disabled" || echo "unknown")
if [ "$FIREWALL_STATE" = "disabled" ]; then
    check_pass "macOS 防火墙已关闭"
elif [ "$FIREWALL_STATE" = "enabled" ]; then
    check_warn "macOS 防火墙已启用"
    echo "   如果 iPhone 无法发现设备，尝试临时关闭防火墙测试"
    echo "   命令: sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off"
else
    check_warn "无法检查防火墙状态"
fi

echo ""
echo "===================="
echo "✅ 验证完成"
echo ""
echo "📱 下一步：在 iPhone 上配对"
echo "   1. 打开家庭 App"
echo "   2. 点击右上角 +"
echo "   3. 选择'添加配件'"
echo "   4. 点击'更多选项...'"
echo "   5. 应该能看到 'Home Assistant Bridge'"
echo "   6. 点击它并输入配对码"
echo ""
echo "🔍 如果看不到设备："
echo "   - 确保 iPhone 和 Mac 在同一 Wi-Fi 网络"
echo "   - 等待 2-3 分钟让 HomeKit 完全启动"
echo "   - 重启容器: docker-compose restart homeassistant"
echo "   - 查看详细文档: docs/HOMEKIT_SETUP.md"
echo ""
