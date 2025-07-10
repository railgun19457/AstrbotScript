# AstrBot 一键部署说明

> 最近更新：2025-07-10
- 适配wechatpadpro最新版v18.6 

## **本脚本仅适用于 Linux 环境下使用 Docker 部署**

## 快速开始

1. 拉取本仓库：
   ```bash
   git clone https://github.com/railgun19457/AstrbotScript.git
   cd ./AstrbotScript
   ```
2. 赋予脚本执行权限：
   ```bash
   chmod +x ./AstrBot.sh
   ```
3. 运行一键部署脚本：
   ```bash
   sudo ./AstrBot.sh
   ```
4. 按提示选择要部署的组件（可多选）：
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

## 官方文档与仓库
- 官方文档：https://astrbot.app/what-is-astrbot.html
- 镜像文档站：https://doc.astrbot.misakanet.site/
- AstrBot 仓库：https://github.com/AstrBotDevs/AstrBot
- WeChatPadPro 仓库：https://github.com/WeChatPadPro/WeChatPadPro


---

## 更新日志

- 2025-07-10：完善文档结构，补充镜像站与仓库链接，权限处理逻辑优化，组件说明细化
