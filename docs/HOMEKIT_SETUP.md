# HomeKit 集成配置指南

本指南详细说明如何在 macOS 上配置 Home Assistant 的 HomeKit 集成。

## 前提条件

- Home Assistant 已安装并运行
- iPhone 或 iPad（iOS 10 或更高版本）
- iPhone 和 Mac 在同一 Wi-Fi 网络

## 配置步骤

### 1. 编辑配置文件

编辑 `~/.homeassistant/configuration.yaml`：

```bash
nano ~/.homeassistant/configuration.yaml
```

添加 HomeKit 配置：

```yaml
homekit:
  filter:
    include_domains:
      - light          # 灯光
      - switch         # 开关
      - climate        # 空调/温控
      - fan            # 风扇
      - cover          # 窗帘/车库门
      - lock           # 门锁
    exclude_entities:
      # 排除特定设备（可选）
      - light.excluded_light
  entity_config:
    # 自定义设备配置（可选）
    light.living_room:
      name: 客厅灯
      # code: "123-45-678"  # 自定义配对码
```

### 2. 重启 Home Assistant

如果使用服务：

```bash
launchctl stop com.homeassistant.server
launchctl start com.homeassistant.server
```

或手动重启（按 Ctrl+C 后重新启动）。

### 3. 查找配对码

查看 Home Assistant 日志：

```bash
tail -f ~/.homeassistant/home-assistant.log | grep -i homekit
```

或在 Web 界面中：
1. 进入 **配置** > **集成**
2. 找到 **HomeKit Bridge**
3. 点击查看配对码

配对码格式：`XXX-XX-XXX`（例如：`123-45-678`）

### 4. 在 iPhone 上配对

1. 打开 **家庭** app
2. 点击右上角 **+** 按钮
3. 选择 **添加配件**
4. 选择 **更多选项...**
5. 找到 **Home Assistant Bridge**
6. 点击 **添加配件**
7. 输入配对码
8. 如果提示"未认证的配件"，选择 **仍然添加**
9. 选择房间并完成设置

### 5. 验证配对

配对成功后，Home Assistant 中的设备会自动出现在家庭 app 中。

## 高级配置

### 自定义设备名称

```yaml
homekit:
  entity_config:
    light.bedroom:
      name: 卧室灯
      type: light
    switch.fan:
      name: 风扇
      type: fan  # 将开关显示为风扇
```

### 设置自定义配对码

```yaml
homekit:
  filter:
    include_domains:
      - light
  entity_config:
    light.living_room:
      code: "123-45-678"
```

### 多个 HomeKit 桥接

如果需要多个桥接（例如分离不同房间）：

```yaml
homekit:
  - name: 客厅
    port: 51827
    filter:
      include_entities:
        - light.living_room
        - switch.living_room_fan
  - name: 卧室
    port: 51828
    filter:
      include_entities:
        - light.bedroom
        - climate.bedroom_ac
```

## 常见问题

### Q: iPhone 找不到 Home Assistant Bridge？

**这是 Docker 环境中最常见的问题！**

**根本原因：**
- HomeKit 依赖 mDNS (Bonjour) 协议进行设备发现
- Docker 的桥接网络模式会阻止 mDNS 广播
- iPhone 无法在局域网中发现 HomeKit Bridge

**解决方案（必须）：**

1. **使用 host 网络模式**（已在 docker-compose.yml 中配置）：
   ```yaml
   services:
     homeassistant:
       network_mode: host  # 关键配置！
   ```

2. **重启容器应用新配置**：
   ```bash
   docker-compose down
   docker-compose up -d
   ```

3. **等待 2-3 分钟**让服务完全启动

4. **在 iPhone 上重新扫描**：
   - 打开家庭 App
   - 点击 + > 添加配件
   - 选择"更多选项"
   - 应该能看到 "Home Assistant Bridge"

**验证配置：**
```bash
# 检查容器网络模式
docker inspect homeassistant | grep NetworkMode
# 应该显示: "NetworkMode": "host"

# 检查 mDNS 广播
dns-sd -B _hap._tcp
# 应该能看到 Home Assistant Bridge
```

**其他检查项：**
- 确认 iPhone 和 Mac 在同一 Wi-Fi 网络
- 关闭 macOS 防火墙或允许传入连接
- 确保 Avahi 容器正在运行：`docker-compose ps avahi`

### Q: 配对失败或超时？

**解决方案：**
1. 确认配对码正确
2. 删除 `~/.homeassistant/.storage/homekit.*` 文件
3. 重启 Home Assistant
4. 重新配对

### Q: 设备在家庭 app 中显示"无响应"？

**解决方案：**
1. 检查 Home Assistant 是否运行
2. 检查设备在 Home Assistant 中是否在线
3. 重启 Home Assistant
4. 如果问题持续，删除并重新添加配件

### Q: 某些设备类型不支持？

**解决方案：**
HomeKit 支持的设备类型有限。可以使用 `type` 参数转换：

```yaml
homekit:
  entity_config:
    switch.heater:
      type: outlet  # 将开关显示为插座
```

支持的类型：
- light
- switch
- outlet
- fan
- thermostat
- lock
- garage_door
- window_covering
- sensor
- binary_sensor

### Q: 如何重置 HomeKit 配对？

```bash
# 停止服务
launchctl stop com.homeassistant.server

# 删除 HomeKit 存储
rm ~/.homeassistant/.storage/homekit.*

# 启动服务
launchctl start com.homeassistant.server
```

## 性能优化

### 减少设备数量

HomeKit 桥接最多支持 150 个配件。如果设备过多：

```yaml
homekit:
  filter:
    include_entities:
      # 只包含常用设备
      - light.living_room
      - light.bedroom
```

### 使用多个桥接

将设备分散到多个桥接可以提高性能。

## 安全建议

1. **使用强配对码**：避免使用简单的配对码如 `111-11-111`
2. **定期更新**：保持 Home Assistant 更新到最新版本
3. **网络隔离**：考虑将智能家居设备放在独立的 VLAN

## 调试

启用 HomeKit 调试日志：

```yaml
logger:
  default: info
  logs:
    homeassistant.components.homekit: debug
```

查看详细日志：

```bash
tail -f ~/.homeassistant/home-assistant.log | grep homekit
```

## 参考资源

- [Home Assistant HomeKit 官方文档](https://www.home-assistant.io/integrations/homekit/)
- [Apple HomeKit 开发者文档](https://developer.apple.com/homekit/)
