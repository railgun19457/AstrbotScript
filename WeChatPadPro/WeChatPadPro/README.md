# WechatPadPro 部署说明

## 项目说明

WechatPadPro 是一个微信辅助工具，提供了丰富的 API 接口，支持群管理、消息收发、朋友圈操作等功能。

## 部署说明

### 1. 镜像说明

本项目的 Docker 镜像已经内置了必要的 `assets/sae.dat` 和 `assets/ca-cert` 文件，其他资源文件需要通过挂载 `assets` 目录的方式提供。

### 2. 目录结构

部署时，请确保以下目录结构：

```
deployment/
├── assets/           # 用户自定义资源目录（可选）
├── .env              # 环境配置文件
└── docker-compose.yml # Docker Compose 配置文件
```

### 3. 使用 Docker Compose 部署

1. 创建部署目录：

```bash
mkdir -p wechatpadpro/assets
cd wechatpadpro
```

2. 创建 `.env` 文件，配置必要的环境变量：

```
# 管理员密钥
ADMIN_KEY=12345

# 服务器配置
HOST=0.0.0.0
PORT=1239
API_VERSION=
DEBUG=true

# Redis配置
REDIS_HOST=wechatpadpro_redis
REDIS_PORT=6379
REDIS_DB=1
REDIS_PASS=123456

# MySQL配置
MYSQL_CONNECT_STR=wechatpadpro:123456@tcp(wechatpadpro_mysql:3306)/wechatpadpro?charset=utf8mb4&parseTime=true&loc=Local
```

3. 创建 `docker-compose.yml` 文件：

```yaml
version: '3.8'

services:
  wechatpadpro:
    image: luolinaiwis/wechatpadpro:latest
    container_name: wechatpadpro
    restart: unless-stopped
    ports:
      - "1239:1239"
    volumes:
      - wechatpadpro_data:/app/data
      - wechatpadpro_logs:/app/logs
      - wechatpadpro_static:/app/static
      - ./assets:/app/assets  # 挂载用户提供的 assets 目录
      - ./.env:/app/.env      # 挂载用户提供的 .env 文件
    environment:
      - DEBUG=true
      - ADMIN_KEY=12345
      - REDIS_HOST=redis
      - REDIS_PASS=123456
      - MYSQL_CONNECT_STR=wechatpadpro:123456@tcp(mysql:3306)/wechatpadpro?charset=utf8mb4&parseTime=true&loc=Local
      - PORT=1239
      - HOST=0.0.0.0
      - TZ=Asia/Shanghai
    depends_on:
      - redis
      - mysql

  redis:
    image: redis:7-alpine
    container_name: wechatpadpro_redis
    restart: unless-stopped
    command: redis-server --requirepass 123456
    volumes:
      - redis_data:/data

  mysql:
    image: mysql:8.0
    container_name: wechatpadpro_mysql
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=123456
      - MYSQL_DATABASE=wechatpadpro
      - MYSQL_USER=wechatpadpro
      - MYSQL_PASSWORD=123456
    volumes:
      - mysql_data:/var/lib/mysql
    command: --default-authentication-plugin=mysql_native_password

volumes:
  wechatpadpro_data:
  wechatpadpro_logs:
  wechatpadpro_static:
  redis_data:
  mysql_data:
```

4. 启动服务：

```bash
docker-compose up -d
```

### 4. 使用 Docker 命令部署

如果不使用 Docker Compose，也可以使用以下 Docker 命令部署：

```bash
# 创建网络
docker network create wechatpadpro-network

# 启动 Redis
docker run -d --name wechatpadpro_redis --network wechatpadpro-network \
  -v redis_data:/data \
  redis:7-alpine redis-server --requirepass 123456

# 启动 MySQL
docker run -d --name wechatpadpro_mysql --network wechatpadpro-network \
  -e MYSQL_ROOT_PASSWORD=123456 \
  -e MYSQL_DATABASE=wechatpadpro \
  -e MYSQL_USER=wechatpadpro \
  -e MYSQL_PASSWORD=123456 \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0 --default-authentication-plugin=mysql_native_password

# 启动 WechatPadPro
docker run -d --name wechatpadpro --network wechatpadpro-network \
  -p 1239:1239 \
  -v /path/to/assets:/app/assets \
  -v /path/to/.env:/app/.env \
  -v wechatpadpro_data:/app/data \
  -v wechatpadpro_logs:/app/logs \
  -v wechatpadpro_static:/app/static \
  luolinaiwis/wechatpadpro:latest
```

### 5. 注意事项

- 镜像内已包含 `assets/sae.dat` 和 `assets/ca-cert` 文件，无需单独提供
- 如果挂载了自己的 `assets` 目录，请确保该目录中包含所有必要的资源文件
- 如果遇到权限问题，可以使用以下命令设置权限：
  ```bash
  chmod -R 755 assets
  ```

## 访问应用

成功部署后，可以通过以下地址访问应用：

```
http://服务器IP:1239
```

默认管理员密钥为 `12345`（可在 .env 文件中修改）。

# 微信Webhook接收客户端

这是一个用于接收和处理微信Webhook消息推送的Python客户端，可以方便地接收微信消息并进行自定义处理。

## 功能特点

- 支持接收微信各种类型的消息（文本、图片、语音、视频等）
- 支持签名验证，确保消息安全性
- 消息持久化存储到SQLite数据库
- 灵活的消息处理回调机制
- 支持自定义消息处理逻辑
- 支持从配置文件加载设置

## 系统要求

- Python 3.6+
- SQLite 3

## 安装方法

1. 克隆代码到本地

```bash
git clone https://github.com/your-username/wechat-webhook-client.git
cd wechat-webhook-client
```

2. 安装依赖

```bash
pip install -r requirements.txt
```

## 快速开始

### 基础使用

1. 修改 `webhook_config.json` 配置文件

```json
{
    "port": 8000,
    "path": "/webhook",
    "secret": "your_secret_key",
    "log_level": "INFO",
    "log_file": "webhook.log"
}
```

2. 启动基础客户端

```bash
python webhook_client.py
```

3. 启动高级客户端（带数据库存储）

```bash
python webhook_client_advanced.py -c webhook_config.json -d webhook_messages.db
```

### 在微信服务端配置Webhook

在微信服务端通过API设置Webhook回调：

```
POST /api/webhook/config?key=YOUR_WECHAT_KEY

{
    "url": "http://your-server-ip:8000/webhook",
    "secret": "your_secret_key",
    "enabled": true,
    "timeout": 10,
    "retryCount": 3,
    "messageTypes": ["1", "3", "49"],
    "includeSelfMessage": true
}
```

| 参数名 | 说明 |
|-------|------|
| url | Webhook接收服务器URL |
| secret | 用于签名验证的密钥 |
| enabled | 是否启用Webhook |
| timeout | 请求超时时间（秒） |
| retryCount | 失败重试次数 |
| messageTypes | 需要推送的消息类型（为空表示所有类型） |
| includeSelfMessage | 是否包含自己发送的消息 |

## 消息类型参考

| 类型值 | 说明 |
|-------|------|
| 1 | 文本消息 |
| 3 | 图片消息 |
| 34 | 语音消息 |
| 43 | 视频消息 |
| 47 | 动画表情 |
| 49 | 应用消息（文件、链接等） |
| 10000 | 系统提示 |

## 自定义消息处理

可以通过继承`MessageProcessor`类和重写对应的处理方法来自定义消息处理逻辑：

```python
from webhook_client_advanced import MessageProcessor, WebhookMessage

class MyMessageProcessor(MessageProcessor):
    def handle_msg_type_1(self, msg: WebhookMessage):
        """自定义文本消息处理逻辑"""
        print(f"收到来自 {msg.from_user} 的消息: {msg.content}")
        
        # 处理关键词回复
        if "你好" in msg.content:
            # 可以调用微信API发送回复
            print("检测到问候，可以在这里实现自动回复")
```

## 常见问题

1. **无法接收到消息**
   
   - 检查服务器端口是否开放
   - 确认Webhook配置中的URL是否正确
   - 查看webhook.log日志排查问题

2. **签名验证失败**
   
   - 确保服务端和客户端的secret一致
   - 检查时间戳是否正确（服务器时间差异过大会导致验证失败）

3. **消息处理异常**
   
   - 查看错误日志
   - 确保消息处理逻辑中没有未捕获的异常

## 安全建议

1. 使用HTTPS提高通信安全性
2. 设置复杂的secret密钥
3. 定期更换secret密钥
4. 在生产环境中限制IP访问

## 许可证

MIT

## 联系方式

如果有任何问题或建议，请提交Issue或发送邮件至您的联系邮箱。 