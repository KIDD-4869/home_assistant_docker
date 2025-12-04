# HomeKit Bridge 无法被 iPhone 发现 - 解决方案

## 问题描述

在 Docker 环境中运行 Home Assistant 时，iPhone 的家庭 App 无法扫描到 HomeKit Bridge。

**症状：**
- ✅ Home Assistant 可以正常访问
- ✅ 米家设备已成功连接到 Home Assistant
- ❌ iPhone 家庭 App 中看不到 "Home Assistant Bridge"
- ❌ 扫描配件时找不到任何设备

## 根本原因

HomeKit 使用 **mDNS (Bonjour)** 协议进行设备发现。在 Docker 环境中：

1. **桥接网络模式**（Docker 默认）会创建独立的网络命名空间
2. 容器内的 mDNS 广播**无法穿透**到主机网络
3. iPhone 在局域网中**无法接收**到 HomeKit Bridge 的广播
4. 因此无法发现设备

### 网络模式对比

| 网络模式 | mDNS 广播 | HomeKit 发现 | 说明 |
|---------|----------|-------------|------|
| **bridge**（默认） | ❌ 被隔离 | ❌ 无法发现 | 容器在独立网络中 |
| **host**（推荐） | ✅ 正常 | ✅ 可以发现 | 容器使用主机网络 |

## 解决方案

### 方法：使用 host 网络模式

让 HomeAssistant 容器直接使用主机网络栈，这样 mDNS 广播就能正常到达局域网。

### 实施步骤

#### 1. 修改 docker-compose.yml

编辑项目根目录的 `docker-compose.yml` 文件：

```yaml
services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    network_mode: host  # 添加这一行！
    volumes:
      - ./config:/config
      - /etc/localtime:/etc/localtime:ro
    restart: unless-stopped
    privileged: true
    # 删除 ports 配置（使用 host 模式时不需要）
    # ports:
    #   - "8123:8123"
    environment:
      - TZ=Asia/Shanghai

  avahi:
    container_name: avahi
    image: flungo/avahi:latest
    network_mode: host  # 保持不变
    volumes:
      - ./avahi:/etc/avahi
    restart: unless-stopped
    environment:
      - AVAHI_HOST_NAME=homeassistant
```

**关键变更：**
- ✅ 添加 `network_mode: host`
- ✅ 删除或注释掉 `ports` 配置（host 模式下不需要）

#### 2. 重启容器

```bash
# 停止容器
docker-compose down

# 启动容器（应用新配置）
docker-compose up -d

# 查看日志确认启动成功
docker-compose logs -f homeassistant
```

#### 3. 等待服务启动

等待 **2-3 分钟**，让 HomeKit Bridge 完全初始化。

#### 4. 验证配置

运行验证脚本：

```bash
./scripts/verify-homekit.sh
```

或手动验证：

```bash
# 检查网络模式
docker inspect homeassistant | grep NetworkMode
# 应该显示: "NetworkMode": "host"

# 检查 mDNS 广播
dns-sd -B _hap._tcp
# 应该能看到 Home Assistant Bridge
```

#### 5. 在 iPhone 上配对

1. 打开 **家庭** App
2. 点击右上角 **+** 按钮
3. 选择 **添加配件**
4. 点击 **更多选项...**
5. 应该能看到 **Home Assistant Bridge**
6. 点击它并输入配对码
7. 如果提示"未认证的配件"，选择 **仍然添加**

**获取配对码：**
- 方法 1：Home Assistant Web 界面 > 设置 > 设备与服务 > HomeKit Bridge
- 方法 2：查看日志 `docker-compose logs homeassistant | grep -i "setup pin"`

## 技术原理

### 为什么 host 模式可以解决问题？

```
┌─────────────────────────────────────┐
│         macOS 主机网络               │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  HomeAssistant (host mode)   │  │
│  │  - 直接使用主机网络栈         │  │
│  │  - mDNS 广播到局域网          │  │
│  │  - 端口直接绑定到主机         │  │
│  └──────────────────────────────┘  │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Avahi (host mode)           │  │
│  │  - 增强 mDNS 支持             │  │
│  └──────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
         ↓ mDNS 广播
    ┌─────────┐
    │ iPhone  │
    │ 家庭 App │
    └─────────┘
```

**host 网络模式的优势：**
1. **无网络隔离**：容器直接使用主机网络栈
2. **mDNS 正常工作**：广播可以到达局域网
3. **性能更好**：无需 NAT 转换
4. **端口直接绑定**：无需端口映射

### 为什么桥接模式不行？

```
┌─────────────────────────────────────┐
│         macOS 主机网络               │
│                                     │
│  ┌──────────────────────────────┐  │
│  │  Docker 桥接网络              │  │
│  │  (172.17.0.0/16)             │  │
│  │                               │  │
│  │  ┌────────────────────────┐  │  │
│  │  │ HomeAssistant          │  │  │
│  │  │ - 独立网络命名空间      │  │  │
│  │  │ - mDNS 被隔离 ❌       │  │  │
│  │  └────────────────────────┘  │  │
│  └──────────────────────────────┘  │
│         ↑ 端口映射 (8123)           │
└─────────────────────────────────────┘
         ↓ mDNS 无法传播 ❌
    ┌─────────┐
    │ iPhone  │
    │ 看不到   │
    └─────────┘
```

## 故障排除

### 问题 1：还是看不到设备

**检查清单：**

1. **确认网络模式**：
   ```bash
   docker inspect homeassistant | grep NetworkMode
   ```
   必须显示 `"NetworkMode": "host"`

2. **确认同一网络**：
   - iPhone 和 Mac 必须在同一 Wi-Fi 网络
   - 不能是访客网络或隔离网络

3. **检查防火墙**：
   ```bash
   # 临时关闭防火墙测试
   sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate off
   ```

4. **重启服务**：
   ```bash
   docker-compose restart homeassistant
   docker-compose restart avahi
   ```

5. **等待更长时间**：
   - HomeKit 初始化可能需要 5 分钟
   - 查看日志：`docker-compose logs -f homeassistant`

### 问题 2：配对失败

**解决方案：**

1. **重置 HomeKit 配对**：
   ```bash
   docker-compose down
   rm config/.storage/homekit.*
   docker-compose up -d
   ```

2. **检查配对码**：
   - 确保输入正确的配对码
   - 格式：XXX-XX-XXX（例如：123-45-678）

3. **重启 iPhone**：
   - 有时 iPhone 的 mDNS 缓存会导致问题

### 问题 3：设备显示"无响应"

**解决方案：**

1. **检查 Home Assistant 状态**：
   ```bash
   docker-compose ps
   curl http://localhost:8123
   ```

2. **检查设备状态**：
   - 在 Home Assistant 中确认设备在线

3. **重启 HomeKit Bridge**：
   - Home Assistant > 设置 > 设备与服务 > HomeKit Bridge > 重新加载

## 安全考虑

### host 网络模式的安全性

**优点：**
- ✅ 在本地开发环境中是安全的
- ✅ 性能更好
- ✅ 配置更简单

**注意事项：**
- ⚠️ 容器可以访问主机所有网络接口
- ⚠️ 不要将 Mac 暴露到公网
- ⚠️ 建议在路由器上配置防火墙

**安全建议：**
1. 只在可信网络中使用
2. 定期更新 Home Assistant
3. 使用强密码
4. 启用双因素认证
5. 不要将 8123 端口暴露到公网

## 参考资料

### 官方文档
- [Home Assistant HomeKit 集成](https://www.home-assistant.io/integrations/homekit/)
- [Docker 网络模式](https://docs.docker.com/network/)
- [Apple HomeKit 协议](https://developer.apple.com/homekit/)

### 相关文档
- [HomeKit 详细配置](HOMEKIT_SETUP.md)
- [快速修复指南](QUICK_FIX_MDNS.md)
- [故障排除](TROUBLESHOOTING.md)

### 社区讨论
- [Home Assistant 社区论坛](https://community.home-assistant.io/)
- [Home Assistant 中文论坛](https://bbs.hassbian.com/)

## 总结

**问题：** Docker 桥接网络隔离 mDNS 广播  
**解决：** 使用 `network_mode: host` 让容器使用主机网络  
**结果：** iPhone 可以发现 HomeKit Bridge  

这是 Docker 环境中运行 HomeKit 的**标准解决方案**，被广泛使用且经过验证。

---

**最后更新**：2024-12-04  
**适用版本**：Home Assistant 2024.x, Docker 20.x+
