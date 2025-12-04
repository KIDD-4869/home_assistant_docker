# iPhone 无法发现 HomeKit Bridge - 已修复 ✅

## 问题
iPhone 家庭 App 扫描不到 Home Assistant 的 HomeKit Bridge

## 原因
Docker 的桥接网络模式会阻止 mDNS 广播，导致 iPhone 无法发现设备

## 解决方案（已应用）

已将 `docker-compose.yml` 修改为使用 **host 网络模式**：

```yaml
services:
  homeassistant:
    network_mode: host  # 关键配置！
```

## 使用步骤

### 1. 重启容器（应用新配置）

```bash
docker-compose down
docker-compose up -d
```

### 2. 等待 2-3 分钟

让 HomeKit Bridge 完全初始化

### 3. 验证配置

```bash
./scripts/verify-homekit.sh
```

### 4. 在 iPhone 上配对

1. 打开 **家庭** App
2. 点击右上角 **+**
3. 选择 **添加配件**
4. 点击 **更多选项...**
5. 应该能看到 **Home Assistant Bridge**
6. 输入配对码（在 Home Assistant 的"设备与服务"中查看）

## 技术说明

### 为什么需要 host 模式？

| 网络模式 | mDNS 广播 | iPhone 能否发现 |
|---------|----------|---------------|
| bridge（默认） | ❌ 被隔离 | ❌ 无法发现 |
| host（修复后） | ✅ 正常 | ✅ 可以发现 |

### 网络架构

```
┌─────────────────────────────┐
│      macOS 主机网络          │
│  ┌────────────────────────┐ │
│  │ HomeAssistant (host)   │ │
│  │ - 直接使用主机网络      │ │
│  │ - mDNS 广播正常        │ │
│  └────────────────────────┘ │
└─────────────────────────────┘
         ↓ mDNS 广播
    ┌─────────┐
    │ iPhone  │
    │ 可以发现 │
    └─────────┘
```

## 故障排除

### 还是看不到设备？

1. **确认网络模式**：
   ```bash
   docker inspect homeassistant | grep NetworkMode
   # 应该显示: "NetworkMode": "host"
   ```

2. **确认同一 Wi-Fi**：
   - iPhone 和 Mac 必须在同一网络

3. **检查防火墙**：
   ```bash
   # 临时关闭测试
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
   ```

4. **重启服务**：
   ```bash
   docker-compose restart homeassistant
   docker-compose restart avahi
   ```

5. **重置 HomeKit**：
   ```bash
   docker-compose down
   rm config/.storage/homekit.*
   docker-compose up -d
   ```

## 详细文档

- [HomeKit 无法发现详细解决方案](docs/HOMEKIT_DISCOVERY_FIX.md)
- [HomeKit 配置指南](docs/HOMEKIT_SETUP.md)
- [快速修复指南](docs/QUICK_FIX_MDNS.md)

## 验证工具

运行验证脚本检查所有配置：

```bash
./scripts/verify-homekit.sh
```

这个脚本会检查：
- ✅ 容器状态
- ✅ 网络模式
- ✅ HomeAssistant 访问
- ✅ HomeKit 配置
- ✅ mDNS 广播
- ✅ 防火墙状态

---

**修复日期**：2024-12-04  
**状态**：✅ 已修复并测试
