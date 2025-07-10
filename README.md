# AstrBot 一键部署说明

**仅适用于 Linux 环境下使用 Docker 部署**

## 快速开始

1. 赋予脚本执行权限：
   ```bash
   chmod +x ./AstrBot.sh
   ```
2. 运行一键部署脚本：
   ```bash
   sudo ./AstrBot.sh
   ```
3. 按提示选择要部署的组件（可多选）：
   - AstrBot
   - NapCat
   - WeChatPadPro
   - 全部部署

## 目录与权限要求
- 脚本会自动检查并创建以下目录（如不存在）：
  - AstrBot: `./data`
  - NapCat: `./napcat/ntqq`、`./data`
  - WeChatPadPro: `./WeChatPadPro`、`./WeChatPadPro/mysql/data`、`./WeChatPadPro/redis/data`、`./WeChatPadPro/redis/conf`
- 脚本会自动赋予 `./WeChatPadPro/redis/conf` 目录写权限，确保 Redis 可正常持久化配置。

## 组件说明

### AstrBot
- 容器名称：`astrbot`
- 面板端口：6185
- 默认账号/密码：`astrbot`

### NapCat
- 容器名称：`napcat`
- 面板端口：6099
- 默认密码：`NapCat`

### WeChatPadPro
- 主程序容器名称：`wechatpadpro`
- 管理面板端口：1239
- Admin_key：12345
- MySQL 容器名称：`wechatpadpro_mysql`
  - 端口：容器内 3306（未对外映射）
  - 数据库名：`wechatpadpro`
  - 用户名：`wechatpadpro`
  - 密码：`wechatpadpro_mysql`
  - Root 密码：`wechatpadpro_mysql`
- Redis 容器名称：`wechatpadpro_redis`
  - 端口：容器内 6379（未对外映射）
  - 密码：`wechatpadpro_redis`
  - 连接主机：`wechatpadpro_redis`
  - 连接密码：`wechatpadpro_redis`

### 其他端口
- 6199：反向 ws

## 其他说明
- 消息平台配置可参考文件夹内图片
- 所有服务均基于 Docker Compose 部署，自动创建所需网络

## 官方文档
[https://astrbot.app/what-is-astrbot.html](https://astrbot.app/what-is-astrbot.html)
