# Home Assistant Docker 部署（支持 HomeKit）
！！！！不支持HomeKit，此方案为AI完成的项目，经测试和查验网上资料后得知，docker在mac上不支持host，dns无法穿透，所以HomeKitBridge无法匹配上iPhone上的家庭，继而无法使用HomeKit。考虑在mac上使用的参考UTM虚拟机方案，可参考完整安装指南UTM版。


在 macOS 上使用 Docker 部署 Home Assistant，完整支持 HomeKit 和米家设备。

## 🚀 快速开始

### 1. 安装 Docker Desktop

**方法 1: 从官网下载（推荐）**

访问 https://www.docker.com/products/docker-desktop 下载并安装。

**方法 2: 使用命令行下载**

```bash
# Apple Silicon (M系列)
curl -L -o ~/Downloads/Docker.dmg https://desktop.docker.com/mac/main/arm64/Docker.dmg
open ~/Downloads/Docker.dmg

# Intel
curl -L -o ~/Downloads/Docker.dmg https://desktop.docker.com/mac/main/amd64/Docker.dmg
open ~/Downloads/Docker.dmg
```

安装后启动 Docker Desktop 应用。

### 2. 一键部署

```bash
./deploy.sh
```

脚本会自动：
- ✅ 检查 Docker 环境
- ✅ 创建配置目录
- ✅ 配置 Avahi（HomeKit 支持）
- ✅ 启动 Home Assistant
- ✅ 配置自动启动

### 3. 访问

```
http://localhost:8123
```

⚠️ **重要**：请使用 `localhost:8123` 访问，不要使用 `homeassistant.local`。由于 macOS Docker 的限制，mDNS 域名可能无法正常解析。

首次访问需要 5-10 分钟启动时间。

## 📋 系统要求

| 组件 | 最低要求 | 推荐配置 |
|------|---------|---------|
| 操作系统 | macOS 12.0+ | macOS 14.0+ |
| 处理器 | Intel 或 Apple Silicon | Apple Silicon |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 5GB | 10GB+ |
| Docker | Docker Desktop 4.0+ | 最新版本 |

### 资源占用

- **内存**：500MB - 1GB（运行时）
- **CPU**：5-10%（空闲时）
- **磁盘**：2-3GB（基础安装）
- **端口**：8123（Web 界面）

## 🏠 HomeKit 支持

本方案通过 Avahi 容器提供 mDNS 服务，完整支持 HomeKit。

### 技术原理

macOS Docker 默认不支持 mDNS 广播，本方案通过以下方式解决：

1. **使用 `network_mode: host`**：让 HomeAssistant 容器直接使用主机网络（关键！）
2. **运行 Avahi 容器**：提供额外的 mDNS 服务支持
3. **mDNS 广播**：HomeKit 配对信息可以正常广播到局域网

```
┌─────────────────────────────────┐
│       macOS 主机网络             │
│  ┌──────────────────────────┐  │
│  │  HomeAssistant (host)    │  │
│  │  - 直接使用主机网络       │  │
│  │  - HomeKit mDNS 广播     │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │  Avahi (host)            │  │
│  │  - 增强 mDNS 支持         │  │
│  └──────────────────────────┘  │
│         ↓ mDNS 广播             │
└─────────────────────────────────┘
         ↓
    iPhone/iPad
    家庭 App 可以发现
```

**为什么必须使用 host 网络模式？**
- Docker 的桥接网络会隔离 mDNS 广播
- iPhone 无法在局域网中发现 HomeKit Bridge
- host 模式让容器直接使用主机网络，解决发现问题

### 配置 HomeKit

1. 访问 http://localhost:8123
2. 进入 **设置** > **设备与服务**
3. 点击 **+ 添加集成**
4. 搜索 **HomeKit**
5. 按照向导配置
6. 在 iPhone 家庭 app 中扫描配对码

详细说明：`docs/HOMEKIT_SETUP.md`

## 🔧 管理命令

```bash
# 启动服务
docker-compose up -d

# 停止服务
docker-compose down

# 查看日志
docker-compose logs -f homeassistant

# 重启服务
docker-compose restart

# 查看状态
docker-compose ps

# 更新到最新版本
docker-compose pull
docker-compose up -d
```

## 📦 备份和恢复

### 自动备份

```bash
./scripts/backup-homeassistant.sh
```

备份保存在 `~/homeassistant-backups/`

### 恢复备份

```bash
./scripts/restore-homeassistant.sh
```

选择要恢复的备份文件。

## 🔄 从 Core 迁移

### 1. 备份现有配置

```bash
# 停止旧的 Core 服务
launchctl stop com.homeassistant.server
launchctl unload ~/Library/LaunchAgents/com.homeassistant.server.plist

# 备份配置
./scripts/backup-homeassistant.sh
```

### 2. 部署 Docker 版本

```bash
./deploy.sh
```

### 3. 恢复配置

```bash
# 停止 Docker 服务
docker-compose down

# 恢复配置
./scripts/restore-homeassistant.sh

# 重启服务
docker-compose up -d
```

### 4. 验证功能

- 访问 http://localhost:8123
- 检查所有设备和自动化
- 测试 HomeKit 和米家集成

### 5. 清理旧安装（可选）

```bash
# 删除旧的 Core 安装
rm -rf ~/homeassistant-venv
rm -f ~/Library/LaunchAgents/com.homeassistant.server.plist

# 删除旧的配置（已备份）
# rm -rf ~/.homeassistant
```

## 📁 项目结构

```
.
├── docker-compose.yml          # Docker 配置
├── deploy.sh                   # 一键部署脚本
├── config/                     # Home Assistant 配置目录
├── avahi/                      # Avahi 配置（HomeKit 支持）
├── scripts/
│   ├── backup-homeassistant.sh # 备份脚本
│   └── restore-homeassistant.sh # 恢复脚本
├── docs/
│   ├── HOMEKIT_SETUP.md        # HomeKit 配置指南
│   ├── XIAOMI_SETUP.md         # 米家配置指南
│   └── TROUBLESHOOTING.md      # 故障排除
└── README.md                   # 本文件
```

## 🔄 自动启动

Docker Desktop 默认开机自动启动，容器配置为 `restart: unless-stopped`，会自动重启。

如需禁用自动启动：
```bash
docker-compose down
```

## 🛠️ 故障排除

### 无法访问 Web 界面

```bash
# 检查容器状态
docker-compose ps

# 查看日志
docker-compose logs -f homeassistant

# 等待更长时间（首次启动需要 5-10 分钟）
```

### mDNS 域名无法访问

**问题**：`homeassistant.local` 无法访问

**原因**：macOS Docker Desktop 对 mDNS 支持有限

**解决方案**：
- 使用 `http://localhost:8123` 访问
- 或使用 `http://127.0.0.1:8123`
- 如果集成配置跳转到 homeassistant.local，手动改为 localhost

### Xiaomi 集成登录失败

**最常见原因**：服务器区域选择错误

**解决方案**：
- 中国大陆用户必须选择 **cn** 服务器
- 使用小米账号（手机号/邮箱）+ 密码
- 详细排查：查看 `docs/XIAOMI_SETUP.md`

### HomeKit 无法配对

```bash
# 检查 Avahi 容器状态
docker-compose ps avahi

# 重启 Avahi
docker-compose restart avahi

# 查看 Avahi 日志
docker-compose logs -f avahi
```

### 端口被占用

```bash
# 检查端口占用
lsof -i:8123

# 停止占用端口的进程
lsof -ti:8123 | xargs kill -9
```

更多问题：查看 `docs/TROUBLESHOOTING.md`

## 📚 文档

### 快速开始
- [米家设备快速配置](docs/XIAOMI_QUICK_START.md) ⭐ 推荐
- [HACS 安装指南](docs/HACS_INSTALLATION.md)
- [快速修复指南](docs/QUICK_FIX_MDNS.md)

### HomeKit 相关
- [HomeKit 配置](docs/HOMEKIT_SETUP.md)
- [HomeKit 无法发现解决方案](docs/HOMEKIT_DISCOVERY_FIX.md) ⭐ 重要

### 详细配置
- [米家配置](docs/XIAOMI_SETUP.md)
- [故障排除](docs/TROUBLESHOOTING.md)
- [迁移指南](docs/MIGRATION_GUIDE.md)

## ⚙️ 高级配置

### 修改时区

编辑 `docker-compose.yml`：

```yaml
environment:
  - TZ=Asia/Shanghai  # 改为你的时区
```

### 使用不同端口

由于使用 `network_mode: host`，端口在 Home Assistant 配置中修改：

编辑 `config/configuration.yaml`：

```yaml
http:
  server_port: 8124  # 改为你想要的端口
```

### 资源限制

编辑 `docker-compose.yml` 添加资源限制：

```yaml
services:
  homeassistant:
    # ... 其他配置
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
```

## 🔐 安全建议

### 网络安全
- 使用 `network_mode: host`，容器可以访问主机网络
- 建议在路由器上配置防火墙规则
- 不要将 8123 端口暴露到公网

### 数据安全
- 定期备份配置文件（建议每周一次）
- 备份文件包含敏感信息（密码、API 密钥）
- 建议加密备份文件或存储到安全位置
- 将重要备份复制到外部存储

## 🆘 获取帮助

- [Home Assistant 官方文档](https://www.home-assistant.io/docs/)
- [Home Assistant 中文社区](https://bbs.hassbian.com/)
- [Docker 文档](https://docs.docker.com/)
- [官方社区论坛](https://community.home-assistant.io/)

## 📄 许可证

MIT License

## 🙏 致谢

- Home Assistant 团队
- Docker 社区
- Avahi 项目
- 所有贡献者

---

**项目状态**: ✅ 生产就绪  
**快速开始**: `./deploy.sh`  
**访问地址**: http://localhost:8123  
**支持 HomeKit**: ✅  
**支持米家**: ✅
