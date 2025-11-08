#!/usr/bin/env bash
# AstrBot / NapCat / WeChatPadPro 一键部署与管理脚本
# 项目地址:https://github.com/railgun19457/AstrbotScript
# 容器配置脚本: https://linuxmirrors.cn

set -euo pipefail

SCRIPT_VERSION="2.0.0"

# ==================== 配置文件加载 ====================
# 获取脚本所在的目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/AstrbotScript.conf"

# 默认配置
BASE_DIR="/opt/AstrBot"           # 服务安装根目录
NETWORK_NAME="astrbot"            # Docker 网络名称
COMPOSE_FILENAME="compose.yml"    # Compose 文件名

# 如果配置文件存在则读取
if [[ -f "$CONFIG_FILE" ]]; then
  # 注意：只读取合法的变量名，忽略注释和空行
  source <(grep -E "^(BASE_DIR|NETWORK_NAME)=" "$CONFIG_FILE")
else
  # 如果配置文件不存在，则创建默认配置文件
  cat >"$CONFIG_FILE" <<'EOF'
# ==================== AstrBot 部署脚本配置文件 ====================
# 此配置文件与脚本在同一目录中
# 脚本启动时会自动读取此文件中的配置

# ==================== 环境配置 ====================
# 服务安装根目录
BASE_DIR="/opt/AstrBot"

# Docker 网络名称
NETWORK_NAME="astrbot"
EOF
fi

# ==================== 颜色定义 ====================
C_RESET=$'\033[0m'
C_GREEN=$'\033[32m'
C_RED=$'\033[31m'
C_YELLOW=$'\033[33m'
C_BLUE=$'\033[34m'

# ==================== 日志函数 ====================
info() { printf "%s\n" "${C_GREEN}[INFO]${C_RESET} $*" >&2; }
warn() { printf "%s\n" "${C_YELLOW}[WARN]${C_RESET} $*" >&2; }
err()  { printf "%s\n" "${C_RED}[ERROR]${C_RESET} $*" >&2; }

# ==================== 工具函数 ====================
require_root(){ 
  if [[ $EUID -ne 0 ]]; then 
    err "需要 root 权限执行 (sudo)。"
    return 1
  fi
  return 0
}

pause(){ 
  read -r -p "按 Enter 继续..." _ || true
}

has_cmd(){ 
  command -v "$1" >/dev/null 2>&1
}

clear_screen(){
  clear 2>/dev/null || printf '\033[2J\033[3J\033[1;1H'
}

# ==================== Docker 检测与安装 ====================
detect_compose_cmd(){
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif has_cmd docker-compose; then
    echo "docker-compose"
  else
    echo ""
  fi
}

check_docker_installed(){
  if has_cmd docker; then
    return 0
  else
    return 1
  fi
}

install_docker(){
  if ! require_root; then
    warn "安装 Docker 需要 root 权限，请使用 sudo 重新运行"
    pause
    return 1
  fi

  info "准备安装并配置 Docker 环境（包含镜像加速）..."
  
  if has_cmd curl; then
    info "使用 curl 下载安装脚本..."
    curl -fsSL https://linuxmirrors.cn/docker.sh | bash
  elif has_cmd wget; then
    info "使用 wget 下载安装脚本..."
    wget -qO- https://linuxmirrors.cn/docker.sh | bash
  else
    err "系统缺少 curl/wget，无法下载安装脚本"
    pause
    return 1
  fi

  if ! check_docker_installed; then
    err "Docker 安装失败或未加入 PATH"
    pause
    return 1
  fi

  DOCKER_COMPOSE_CMD="$(detect_compose_cmd || true)"
  if [[ -z "$DOCKER_COMPOSE_CMD" ]]; then
    warn "⚠️  Compose 未检测到，可能需要手动安装"
  fi
  
  info "✓ Docker 环境安装和配置完成"
  pause
}

# ==================== 网络与目录初始化 ====================
# 初始化 Docker 网络
init_network(){
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    info "正在创建 Docker 网络: $NETWORK_NAME"
    if ! docker network create --driver bridge "$NETWORK_NAME" >/dev/null 2>&1; then
      err "创建网络失败，请检查 Docker 是否运行"
      return 1
    fi
    info "✓ 网络创建成功"
  else
    info "✓ 使用已存在的网络: $NETWORK_NAME"
  fi
  return 0
}

# 初始化安装目录
init_base_dir(){
  if ! mkdir -p -- "$BASE_DIR" 2>/dev/null; then
    err "无法创建目录: $BASE_DIR"
    return 1
  fi
  info "✓ 安装根目录: $BASE_DIR"
  return 0
}

ensure_dirs(){
  local base="$1"; shift
  for d in "$@"; do
    mkdir -p -- "$base/$d" || {
      err "无法创建目录: $base/$d"
      return 1
    }
  done
  return 0
}

# ==================== 服务配置生成 ====================
ensure_wechat_env(){
  local wechat_dir="$1"
  local env_file="$wechat_dir/.env"
  
  cat >"$env_file" <<'EOF'
# ==========================================
# 基础系统配置
# ==========================================
# 是否开启调试模式（true: 开启，false: 关闭）
DEBUG=false
# 服务监听地址（0.0.0.0表示监听所有网卡）
HOST=0.0.0.0
# 服务端口号
PORT=1238
# API版本前缀（如 /v1, /v2）
API_VERSION=
# MCP服务端口（用于AI大模型集成服务）
MCP_PORT=8099
# 推广公众号微信ID（用于新用户首次登录时推广）
GH_WXID=
# 管理员密钥（建议使用复杂的随机字符串）
ADMIN_KEY=wxpadpro1238
# ==========================================
# Redis配置
# ==========================================
# Redis服务器地址
REDIS_HOST=redis_wx
# Redis密码（留空表示不使用密码）
REDIS_PASS=wxpadproredis
# Redis端口
REDIS_PORT=6379
# Redis数据库编号
REDIS_DB=1
# Redis最大空闲连接数
REDIS_MAX_IDLE=30
# Redis最大活动连接数
REDIS_MAX_ACTIVE=100
# Redis空闲连接超时时间（毫秒）
REDIS_IDLE_TIMEOUT=5000
# Redis连接最大生命周期（秒）
REDIS_MAX_CONN_LIFETIME=3600
# Redis连接超时时间（毫秒）
REDIS_CONNECT_TIMEOUT=5000
# Redis读取超时时间（毫秒）
REDIS_READ_TIMEOUT=10000
# Redis写入超时时间（毫秒）
REDIS_WRITE_TIMEOUT=10000
# ==========================================
# MySQL配置
# ==========================================
# MySQL连接字符串（格式：用户名:密码@tcp(主机:端口)/数据库名?参数）
MYSQL_CONNECT_STR="weixin:wxpadprodb@tcp(db_wx:3306)/weixin?charset=utf8mb4&parseTime=true&loc=Local"
# ==========================================
# 应用配置
# ==========================================
# 时区设置
TZ=Asia/Shanghai
# 工作池大小（并发处理任务的goroutine数量）
WORKER_POOL_SIZE=500
# 工作池最大任务队列长度
MAX_WORKER_TASK_LEN=1000
# Web域名（设置为localhost:1238表示使用本地服务器，留空则不上报状态）
WEB_DOMAIN=localhost:1238
# Web任务名称
WEB_TASK_NAME=
# Web任务应用编号
WEB_TASK_APP_NUMBER=
# 是否按微信ID同步消息
NEWS_SYN_WXID=true
# 是否启用DT
DT=true
# ==========================================
# 消息队列配置
# ==========================================
# 消息主题
TOPIC=wx_sync_msg_topic
# 是否启用RocketMQ
ROCKET_MQ_ENABLED=false
# RocketMQ服务器地址
ROCKET_MQ_HOST=127.0.0.1:9876
# RocketMQ访问密钥
ROCKET_ACCESS_KEY=123
# RocketMQ密钥
ROCKET_SECRET_KEY="123!#@13$"
# 是否启用RabbitMQ
RABBIT_MQ_ENABLED=false
# RabbitMQ连接URL（格式：amqp://用户名:密码@主机:端口/）
RABBIT_MQ_URL="amqp://yunkong:123456@127.0.0.1:5672/"
# 是否启用Kafka
KAFKA_ENABLED=false
# Kafka服务器地址列表
KAFKA_URL=
# Kafka用户名
KAFKA_USERNAME=
# Kafka密码
KAFKA_PASSWORD=
# ==========================================
# 任务配置
# ==========================================
# 任务重试次数
TASK_RETRY_COUNT=3
# 任务重试间隔（秒）
TASK_RETRY_INTERVAL=5
# 心跳包间隔（秒）
HEARTBEAT_INTERVAL=25
# 自动认证间隔（分钟）
AUTO_AUTH_INTERVAL=30
# 自动同步间隔（分钟）
AUTO_SYNC_INTERVAL_MINUTES=30
# 任务执行等待时间（毫秒）
TASK_EXEC_WAIT_TIMES=500
# 队列过期时间（秒）
QUEUE_EXPIRE_TIME=86400
# ==========================================
# WebSocket配置
# ==========================================
# WebSocket握手超时时间（秒）
WS_HANDSHAKE_TIMEOUT=10
# WebSocket读缓冲区大小（字节）
WS_READ_BUFFER_SIZE=4096
# WebSocket写缓冲区大小（字节）
WS_WRITE_BUFFER_SIZE=4096
# WebSocket读取超时时间（秒）
WS_READ_DEADLINE=120
# WebSocket写入超时时间（秒）
WS_WRITE_DEADLINE=60
# WebSocket心跳间隔（秒）
WS_PING_INTERVAL=25
# WebSocket连接检查间隔（秒）
WS_CONNECTION_CHECK_INTERVAL=45
# WebSocket最大消息大小（字节）
WS_MAX_MESSAGE_SIZE=8192
# ==========================================
# 集群配置
# ==========================================
# 集群名称
CLUSTER_NAME=
# ZooKeeper地址
ZK_ADDR=
# ETCD地址
ETCD_ADDR=
# ==========================================
# 禁用命令配置
# ==========================================
# 禁用命令列表（逗号分隔）
DISABLED_CMD_LIST=
# ==========================================
# Docker配置
# ==========================================
# MySQL root密码
MYSQL_ROOT_PASSWORD=wxpadprodbroot
# MySQL数据库
MYSQL_DATABASE=weixin
# MySQL用户名
MYSQL_USER=weixin
# MySQL密码
MYSQL_PASSWORD=wxpadprodb
EOF
  
  info "✓ 已生成 WeChatPadPro .env 文件: $env_file"
}

# ==================== Compose 文件生成 ====================
# 生成完整的 compose.yml（包含所有服务定义）
generate_full_compose(){
  local outfile="$1"
  
  cat >"$outfile" <<COMPOSE_EOF
services:
  astrbot:
    image: soulter/astrbot:latest
    container_name: astrbot
    restart: always
    environment:
      - TZ=Asia/Shanghai
    ports:
      - "6185:6185"
    volumes:
      - ./astrbot/data:/AstrBot/data
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - astrbot
    cpus: 1.0
    mem_limit: 1g

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    restart: always
    environment:
      - NAPCAT_UID=\${NAPCAT_UID:-1000}
      - NAPCAT_GID=\${NAPCAT_GID:-1000}
      - MODE=astrbot
    ports:
      - "6099:6099"
    volumes:
      - ./astrbot/data:/AstrBot/data
      - ./napcat/ntqq:/app/.config/QQ
      - ./napcat/config:/app/napcat/config
    networks:
      - astrbot
    mac_address: "02:42:ac:11:00:02"
    cpus: 1.0
    mem_limit: 1g

  wechatpadpro:
    image: wechatpadpro/wechatpadpro:latest
    container_name: wechatpadpro
    restart: always
    ports:
      - "1238:1238"
    env_file:
      - ./wechatpadpro/.env
    environment:
      - DB_HOST=db_wx
      - REDIS_HOST=redis_wx
      - TZ=\${TZ}
      - GH_WXID=\${GH_WXID}
      - ADMIN_KEY=\${ADMIN_KEY}
      - WORKER_POOL_SIZE=\${WORKER_POOL_SIZE}
      - MAX_WORKER_TASK_LEN=\${MAX_WORKER_TASK_LEN}
      - WEB_DOMAIN=\${WEB_DOMAIN}
      - WEB_TASK_NAME=\${WEB_TASK_NAME}
      - WEB_TASK_APP_NUMBER=\${WEB_TASK_APP_NUMBER}
      - NEWS_SYN_WXID=\${NEWS_SYN_WXID}
      - DT=\${DT}
      - TOPIC=\${TOPIC}
      - ROCKET_MQ_ENABLED=\${ROCKET_MQ_ENABLED}
      - ROCKET_MQ_HOST=\${ROCKET_MQ_HOST}
      - ROCKET_ACCESS_KEY=\${ROCKET_ACCESS_KEY}
      - ROCKET_SECRET_KEY=\${ROCKET_SECRET_KEY}
      - RABBIT_MQ_ENABLED=\${RABBIT_MQ_ENABLED}
      - RABBIT_MQ_URL=\${RABBIT_MQ_URL}
      - KAFKA_ENABLED=\${KAFKA_ENABLED}
      - KAFKA_URL=\${KAFKA_URL}
      - KAFKA_USERNAME=\${KAFKA_USERNAME}
      - KAFKA_PASSWORD=\${KAFKA_PASSWORD}
      - TASK_RETRY_COUNT=\${TASK_RETRY_COUNT}
      - TASK_RETRY_INTERVAL=\${TASK_RETRY_INTERVAL}
      - HEARTBEAT_INTERVAL=\${HEARTBEAT_INTERVAL}
      - AUTO_AUTH_INTERVAL=\${AUTO_AUTH_INTERVAL}
      - AUTO_SYNC_INTERVAL_MINUTES=\${AUTO_SYNC_INTERVAL_MINUTES}
      - TASK_EXEC_WAIT_TIMES=\${TASK_EXEC_WAIT_TIMES}
      - QUEUE_EXPIRE_TIME=\${QUEUE_EXPIRE_TIME}
      - WS_HANDSHAKE_TIMEOUT=\${WS_HANDSHAKE_TIMEOUT}
      - WS_READ_BUFFER_SIZE=\${WS_READ_BUFFER_SIZE}
      - WS_WRITE_BUFFER_SIZE=\${WS_WRITE_BUFFER_SIZE}
      - WS_READ_DEADLINE=\${WS_READ_DEADLINE}
      - WS_WRITE_DEADLINE=\${WS_WRITE_DEADLINE}
      - WS_PING_INTERVAL=\${WS_PING_INTERVAL}
      - WS_CONNECTION_CHECK_INTERVAL=\${WS_CONNECTION_CHECK_INTERVAL}
      - WS_MAX_MESSAGE_SIZE=\${WS_MAX_MESSAGE_SIZE}
      - CLUSTER_NAME=\${CLUSTER_NAME}
      - ZK_ADDR=\${ZK_ADDR}
      - ETCD_ADDR=\${ETCD_ADDR}
      - DISABLED_CMD_LIST=\${DISABLED_CMD_LIST}
      - MYSQL_CONNECT_STR=\${MYSQL_CONNECT_STR}
    volumes:
      - ./wechatpadpro/.env:/app/.env
    depends_on:
      mariadb:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - astrbot
    cpus: 0.5
    mem_limit: 512m

  mariadb:
    image: mariadb:10.6
    container_name: db_wx
    restart: always
    environment:
      MYSQL_ROOT_PASSWORD: \${MYSQL_ROOT_PASSWORD:-root123456}
      MYSQL_DATABASE: \${MYSQL_DATABASE:-weixin}
      MYSQL_USER: \${MYSQL_USER:-weixin}
      MYSQL_PASSWORD: \${MYSQL_PASSWORD:-weixin123}
    volumes:
      - ./wechatpadpro/mysql:/var/lib/mysql
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -p\${MYSQL_ROOT_PASSWORD} || exit 1"]
      interval: 5s
      timeout: 5s
      retries: 20
    cpus: 0.5
    mem_limit: 512m
    networks:
      - astrbot

  redis:
    image: redis:7-alpine
    container_name: redis_wx
    restart: always
    command: redis-server --appendonly yes
    volumes:
      - ./wechatpadpro/redis:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 5s
      retries: 20
    cpus: 0.5
    mem_limit: 512m
    networks:
      - astrbot

networks:
  astrbot:
    external: true
    name: $NETWORK_NAME
COMPOSE_EOF

  info "✓ 已生成完整的 compose 文件: $outfile"
}

# ==================== 服务检测与管理 ====================
# 从运行中的容器检测已安装的服务列表
detect_installed_services(){
  local -a detected_services=()
  
  # 检查三个主服务容器是否存在（不管是否运行）
  for svc_name in astrbot napcat wechatpadpro; do
    if docker ps -a --filter "name=$svc_name" --format '{{.Names}}' 2>/dev/null | grep -q "^$svc_name$"; then
      detected_services+=("$svc_name")
    fi
  done
  
  printf '%s\n' "${detected_services[@]}"
}


# ==================== 菜单系统 ====================
# ==================== 配置保存 ====================
save_config(){
  cat >"$CONFIG_FILE" <<EOF
# ==================== AstrBot 部署脚本配置文件 ====================
# 此配置文件与脚本在同一目录中
# 脚本启动时会自动读取此文件中的配置

# ==================== 环境配置 ====================
# 服务安装根目录
BASE_DIR="$BASE_DIR"

# Docker 网络名称
NETWORK_NAME="$NETWORK_NAME"
EOF
}

# ==================== 设置菜单 ====================
menu_settings(){
  while true; do
    clear_screen
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
           环境配置设置
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

当前配置:
  📁 安装目录:  $BASE_DIR
  🌐 网络名称:  $NETWORK_NAME

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

修改选项:
  1) 修改安装目录
  2) 修改网络名称
  
  0) 返回主菜单

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    read -r -p "请选择 (0-2): " opt || true

    case "$opt" in
      1)
        clear_screen
        echo "当前安装目录: $BASE_DIR"
        read -r -p "请输入新的安装目录 (留空保持不变): " new_base || true
        if [[ -n "$new_base" ]]; then
          BASE_DIR="$new_base"
          save_config
          info "✓ 安装目录已更新为: $BASE_DIR"
          info "✓ 配置已保存到: $CONFIG_FILE"
        else
          info "✓ 安装目录保持不变"
        fi
        pause
        ;;
      2)
        clear_screen
        echo "当前网络名称: $NETWORK_NAME"
        read -r -p "请输入新的网络名称 (留空保持不变): " new_network || true
        if [[ -n "$new_network" ]]; then
          NETWORK_NAME="$new_network"
          save_config
          info "✓ 网络名称已更新为: $NETWORK_NAME"
          info "✓ 配置已保存到: $CONFIG_FILE"
        else
          info "✓ 网络名称保持不变"
        fi
        pause
        ;;
      0) return 0 ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 服务选择菜单 ====================
menu_install_services(){
  local selected_astrbot=0 selected_napcat=0 selected_wechat=0

  while true; do
    clear_screen
    
    local astrbot_mark="[ ]" napcat_mark="[ ]" wechat_mark="[ ]"
    [[ $selected_astrbot -eq 1 ]] && astrbot_mark="[✓]"
    [[ $selected_napcat -eq 1 ]] && napcat_mark="[✓]"
    [[ $selected_wechat -eq 1 ]] && wechat_mark="[✓]"

    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          选择需要部署的服务
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${astrbot_mark} 1) AstrBot
${napcat_mark} 2) NapCat
${wechat_mark} 3) WeChatPadPro

      4) 开始安装
      5) 返回主菜单
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    read -r -p "请选择 (1-5): " opt || true

    case "$opt" in
      1) selected_astrbot=$((1-selected_astrbot)) ;;
      2) selected_napcat=$((1-selected_napcat)) ;;
      3) selected_wechat=$((1-selected_wechat)) ;;
      4)
        if (( !selected_astrbot && !selected_napcat && !selected_wechat )); then
          warn "❌ 请至少选择一个服务"
          pause
          continue
        fi
        
        # 生成服务类型列表
        local service_types=()
        (( selected_astrbot )) && service_types+=("astrbot")
        (( selected_napcat )) && service_types+=("napcat")
        (( selected_wechat )) && service_types+=("wechatpadpro")
        
        # 调用安装函数，传递所有选中的服务
        install_service_begin "${service_types[@]}"
        return 0
        ;;
      5) return 0 ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

install_service_begin(){
  local -a service_types=("$@")
  
  if ! require_root; then
    warn "安装服务需要 root 权限"
    pause
    return 1
  fi

  # 检查 Docker
  if [[ -z "$(detect_compose_cmd)" ]]; then
    warn "未检测到 Docker Compose，准备安装..."
    if ! install_docker; then
      err "Docker 安装失败"
      pause
      return 1
    fi
  fi

  # 初始化网络和目录
  if ! init_network || ! init_base_dir; then
    pause
    return 1
  fi

  if [[ ${#service_types[@]} -eq 0 ]]; then
    err "没有选择任何服务"
    pause
    return 1
  fi

  info "本次将部署的服务: $(printf '%s ' "${service_types[@]}")"
  
  # 创建各服务的数据目录
  for svc_type in "${service_types[@]}"; do
    case "$svc_type" in
      astrbot)
        ensure_dirs "$BASE_DIR/astrbot" "data" || return 1
        ;;
      napcat)
        ensure_dirs "$BASE_DIR/napcat" "ntqq" "config" || return 1
        ;;
      wechatpadpro)
        ensure_dirs "$BASE_DIR/wechatpadpro" "mysql" "redis" || return 1
        # 仅在第一次创建 wechatpadpro 时生成 .env
        if [[ ! -f "$BASE_DIR/wechatpadpro/.env" ]]; then
          ensure_wechat_env "$BASE_DIR/wechatpadpro" || return 1
        else
          info "✓ WeChatPadPro .env 文件已存在，跳过生成"
        fi
        ;;
    esac
  done

  # 在基目录生成完整的 compose.yml（包含所有服务定义）
  local compose_file="$BASE_DIR/$COMPOSE_FILENAME"
  generate_full_compose "$compose_file" || return 1
  
  # 启动选中的服务
  info "正在启动选中的服务..."
  local compose_cmd
  compose_cmd="$(detect_compose_cmd)"
  
  if [[ -z "$compose_cmd" ]]; then
    warn "未检测到 compose 命令，请手动运行: cd '$BASE_DIR' && docker compose up -d ${service_types[*]}"
  else
    local start_cmd="cd '$BASE_DIR'"
    
    # 如果包含 wechatpadpro，则需要加载 .env
    if printf '%s\n' "${service_types[@]}" | grep -q "wechatpadpro"; then
      if [[ -f "$BASE_DIR/wechatpadpro/.env" ]]; then
        start_cmd="$start_cmd && set -a && source ./wechatpadpro/.env && set +a"
      fi
    fi
    
    # 启动指定的服务
    start_cmd="$start_cmd && $compose_cmd up -d ${service_types[*]}"
    
    if eval "$start_cmd"; then
      info "✓ 服务部署成功！"
      info "   已部署的服务: $(printf '%s ' "${service_types[@]}")"
      info "   基目录: $BASE_DIR"
      info "   网络: $NETWORK_NAME"
    else
      err "服务启动失败，请检查配置"
      pause
      return 1
    fi
  fi
  
  pause
}

# ==================== Compose 命令执行 ====================
compose_exec(){
  local dir="$1"; shift
  local compose_cmd
  compose_cmd="$(detect_compose_cmd)"
  
  if [[ -z "$compose_cmd" ]]; then
    err "未检测到 docker compose 命令"
    return 2
  fi
  
  # 检查是否有 wechatpadpro .env 文件，如果有则在 subshell 中加载
  local cmd="cd '$dir'"
  
  if [[ -f "$dir/wechatpadpro/.env" ]]; then
    cmd="$cmd && set -a && source ./wechatpadpro/.env && set +a"
  fi
  cmd="$cmd && $compose_cmd"
  for arg in "$@"; do
    cmd="$cmd '$arg'"
  done
  
  eval "$cmd"
}

# ==================== 服务操作 ====================
start_service(){
  local base="$1" service_name="$2"
  info "正在启动 $service_name 服务..."
  
  # 如果启动 wechatpadpro，先启动其依赖的 redis 和 mariadb
  if [[ "$service_name" == "wechatpadpro" ]]; then
    for dep_svc in db_wx redis_wx; do
      docker start "$dep_svc" 2>/dev/null || true
    done
    info "✓ 已同时启动依赖服务: db_wx (MariaDB), redis_wx (Redis)"
  fi
  
  # 先尝试通过 docker compose 启动
  if compose_exec "$base" up -d "$service_name" 2>/dev/null; then
    info "✓ $service_name 服务已启动"
  else
    # 如果 compose 启动失败，直接用 docker start 尝试启动已存在的容器
    if docker start "$service_name" 2>/dev/null; then
      info "✓ $service_name 容器已启动"
    else
      err "启动失败 - 容器不存在或启动出错"
    fi
  fi
  pause
}

stop_service(){
  local base="$1" service_name="$2"
  info "正在停止 $service_name 服务..."
  
  # 先尝试通过 docker compose 停止
  if compose_exec "$base" stop "$service_name" 2>/dev/null; then
    info "✓ $service_name 服务已停止"
  else
    # 如果 compose 停止失败，直接用 docker stop 尝试停止容器
    if docker stop "$service_name" 2>/dev/null; then
      info "✓ $service_name 容器已停止"
    else
      warn "容器已停止或不存在"
    fi
  fi
  
  # 如果停止 wechatpadpro，也停止其依赖的 redis 和 mariadb
  if [[ "$service_name" == "wechatpadpro" ]]; then
    for dep_svc in redis_wx db_wx; do
      docker stop "$dep_svc" 2>/dev/null || true
    done
    info "✓ 已同时停止依赖服务: db_wx (MariaDB), redis_wx (Redis)"
  fi
  
  pause
}

restart_service(){
  local base="$1" service_name="$2"
  info "正在重启 $service_name 服务..."
  
  # 如果重启 wechatpadpro，先重启其依赖的 redis 和 mariadb
  if [[ "$service_name" == "wechatpadpro" ]]; then
    for dep_svc in db_wx redis_wx; do
      docker restart "$dep_svc" 2>/dev/null || true
    done
    info "✓ 已同时重启依赖服务: db_wx (MariaDB), redis_wx (Redis)"
  fi
  
  # 先尝试通过 docker compose 重启
  if compose_exec "$base" restart "$service_name" 2>/dev/null; then
    info "✓ $service_name 服务已重启"
  else
    # 如果 compose 重启失败，直接用 docker restart 尝试重启容器
    if docker restart "$service_name" 2>/dev/null; then
      info "✓ $service_name 容器已重启"
    else
      err "重启失败 - 容器不存在或不在运行状态"
    fi
  fi
  pause
}

show_service_logs(){
  local base="$1" service_name="$2"
  
  info "正在获取 $service_name 服务的日志（按 Ctrl+C 退出）..."
  docker logs -f --tail 100 "$service_name" 2>/dev/null || err "无法获取日志 - 容器不存在"
}

rebuild_service(){
  local base="$1" service_name="$2"
  
  warn "这会重新拉取 $service_name 镜像和重建容器"
  read -r -p "确认? (Y/N): " confirm || true
  
  if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
    info "已取消"
    pause
    return 0
  fi

  info "正在重新构建 $service_name 服务..."
  if compose_exec "$base" pull "$service_name" && compose_exec "$base" up -d --build "$service_name"; then
    info "✓ $service_name 服务重建成功"
    
    # 如果重建 wechatpadpro，也重建其依赖的 redis 和 mariadb
    if [[ "$service_name" == "wechatpadpro" ]]; then
      info "正在重建 WeChatPadPro 的依赖服务..."
      for dep_svc in mariadb redis; do
        if compose_exec "$base" pull "$dep_svc" && compose_exec "$base" up -d --build "$dep_svc"; then
          info "✓ $dep_svc 重建成功"
        else
          warn "⚠️  $dep_svc 重建失败"
        fi
      done
      info "✓ 已同时重建依赖服务: mariadb (MariaDB), redis (Redis)"
    fi
  else
    err "重建失败"
  fi
  pause
}

# ==================== Compose 文件操作 ====================
delete_service(){
  local base="$1" service_name="$2"
  
  clear_screen
  cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
          删除 $service_name 服务确认
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1) 删除容器 (保留数据)
  2) 删除容器和数据 (完全删除)
  3) 取消

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
  
  read -r -p "选择 (1-3): " delete_choice || true

  case "$delete_choice" in
    1)
      warn "删除 $service_name 容器（保留数据目录: $base/$service_name）"
      read -r -p "确认? (Y/N): " confirm || true
      if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
        docker rm -f "$service_name" 2>/dev/null || true
        info "✓ $service_name 容器已删除，数据已保留"
      fi
      ;;
    2)
      err "⚠️  删除 $service_name 容器和所有数据"
      read -r -p "确认完全删除? (Y/N): " confirm || true
      if [[ "$confirm" == "Y" || "$confirm" == "y" ]]; then
        # 删除指定服务及其关联的依赖服务
        local services_to_delete=("$service_name")
        
        # 如果删除 wechatpadpro，也删除其依赖的 redis 和 mariadb
        if [[ "$service_name" == "wechatpadpro" ]]; then
          services_to_delete+=("redis_wx" "db_wx")
        fi
        
        # 删除所有相关容器
        for svc in "${services_to_delete[@]}"; do
          docker rm -fv "$svc" 2>/dev/null || true
        done
        
        # 删除该服务的数据目录
        rm -rf -- "$base/$service_name"
        
        # 如果删除了 wechatpadpro，也删除 redis 和 mariadb 的数据
        if [[ "$service_name" == "wechatpadpro" ]]; then
          rm -rf -- "$base/wechatpadpro/redis"
          rm -rf -- "$base/wechatpadpro/mysql"
        fi
        
        info "✓ $service_name 服务已完全删除"
        if [[ "$service_name" == "wechatpadpro" ]]; then
          info "   已同时删除依赖服务: db_wx (MariaDB), redis_wx (Redis)"
        fi
      fi
      ;;
    3)
      info "已取消"
      ;;
    *)
      warn "无效选择"
      ;;
  esac
  
  pause
}

# ==================== 服务状态显示 ====================
show_all_services_status(){
  clear_screen
  
  cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                        服务状态
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

  local compose_cmd="$(detect_compose_cmd)"
  [[ -z "$compose_cmd" ]] && { err "Docker Compose 未安装"; pause; return 1; }
  
  if [[ ! -d "$BASE_DIR" ]]; then
    err "基目录不存在: $BASE_DIR"
    pause
    return 1
  fi
  
  cd "$BASE_DIR" || { err "无法进入 $BASE_DIR"; pause; return 1; }
  
  # 表头（调整列宽以适应内容）
  printf "%-12s %-14s %-18s %-22s %-36s\n" "状态" "服务名" "容器IP" "镜像" "端口"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  
  # 定义所有可能的服务
  local all_services=("astrbot" "napcat" "wechatpadpro")
  
  for svc in "${all_services[@]}"; do
    local container_name="$svc"
    
    # 检查该服务是否已安装
    if [[ ! -d "$BASE_DIR/$svc" ]]; then
      printf "%-12s %-14s %-16s %-20s %-30s\n" "⚠️  未安装" "$svc" "-" "-" "-"
      continue
    fi
    
    # 检查容器是否存在和运行状态
    local container_exists
    container_exists=$(docker ps -a --filter "name=$container_name" --format '{{.Names}}' 2>/dev/null | head -1)
    
    if [[ -z "$container_exists" ]]; then
      printf "%-12s %-14s %-16s %-20s %-30s\n" "❌ 未运行" "$svc" "-" "-" "-"
      continue
    fi
    
    local status="$(docker ps --filter "name=$container_name" --format '{{.Status}}' 2>/dev/null || echo '')"
    local status_icon="❌ 未运行"
    if [[ "$status" == *"Up"* ]]; then
      status_icon="✅ 运行中"
    fi
    
    # 获取容器IP、镜像名和端口信息
    local container_ip="$(docker inspect "$container_name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo '-')"
    local image="$(docker ps -a --filter "name=$container_name" --format '{{.Image}}' 2>/dev/null || echo '-')"
    local ports="$(docker ps -a --filter "name=$container_name" --format '{{.Ports}}' 2>/dev/null | sed 's/0\.0\.0\.0://g' | tr '\n' ' ' || echo '-')"
    [[ -z "$ports" || "$ports" == " " ]] && ports="-"
    
    printf "%-12s %-14s %-16s %-20s %-30s\n" "$status_icon" "$svc" "$container_ip" "$image" "$ports"
  done
  
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  pause
}

# ==================== 服务子菜单 ====================
menu_service_submenu(){
  local service_name="$1"
  
  while true; do
    clear_screen
    
    # 通过 docker ps 判断服务状态
    local status_icon="⚠️  未安装"
    local container_ip="-"
    local image="-"
    local ports="-"
    
    # 检查容器是否存在（包括未运行的）
    local container_exists
    container_exists=$(docker ps -a --filter "name=$service_name" --format '{{.Names}}' 2>/dev/null | head -1)
    
    if [[ -n "$container_exists" ]]; then
      # 容器存在，检查是否运行中
      local running_status
      running_status=$(docker ps --filter "name=$service_name" --format '{{.Status}}' 2>/dev/null)
      
      if [[ -n "$running_status" ]]; then
        status_icon="✅ 运行中"
        # 获取容器详细信息
        container_ip="$(docker inspect "$service_name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo '-')"
        image="$(docker inspect "$service_name" --format '{{.Config.Image}}' 2>/dev/null || echo '-')"
        ports="$(docker port "$service_name" 2>/dev/null | sed 's/0\.0\.0\.0://g' | tr '\n' ' ' || echo '-')"
        [[ -z "$ports" || "$ports" == " " ]] && ports="-"
      else
        status_icon="❌ 未运行"
        # 获取镜像信息（即使未运行也能显示）
        image="$(docker ps -a --filter "name=$service_name" --format '{{.Image}}' 2>/dev/null || echo '-')"
      fi
    fi
    
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      $service_name 管理菜单
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

服务状态: $status_icon
容器名称: $service_name
镜像名称: $image
容器IP: $container_ip
端口映射: $ports

操作选项:
  1) 启动服务
  2) 停止服务
  3) 重启服务
  4) 查看服务日志
  5) 重建服务 (更新镜像)
  6) 删除服务

  0) 返回上级菜单

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    read -r -p "请选择 (0-6): " opt || true

    case "$opt" in
      1) start_service "$BASE_DIR" "$service_name" ;;
      2) stop_service "$BASE_DIR" "$service_name" ;;
      3) restart_service "$BASE_DIR" "$service_name" ;;
      4) show_service_logs "$BASE_DIR" "$service_name" ;;
      5) rebuild_service "$BASE_DIR" "$service_name" ;;
      6) delete_service "$BASE_DIR" "$service_name" ;;
      0) break ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 主菜单 ====================
main_menu(){
  while true; do
    clear_screen
    cat <<EOF
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      AstrBot 集成部署与管理脚本 v2.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 环境配置:
  1) 安装并配置 Docker 环境
     (使用Linuxmirrors脚本)
  2) ⚙️  环境设置
     (修改安装目录和网络名称)

 服务管理:
  3) 部署新服务
  4) 查看服务状态

 已部署服务管理:
  5) AstrBot
  6) NapCat
  7) WeChatPadPro

  0) 退出脚本

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF

    read -r -p "请选择 (0-7): " opt || true

    case "$opt" in
      1) install_docker ;;
      2) menu_settings ;;
      3) menu_install_services ;;
      4) show_all_services_status ;;
      5) menu_service_submenu "astrbot" ;;
      6) menu_service_submenu "napcat" ;;
      7) menu_service_submenu "wechatpadpro" ;;
      0) 
        clear_screen
        info "感谢使用，再见！"
        break 
        ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 主程序入口 ====================

if [[ "${1:-}" == "--version" ]] || [[ "${1:-}" == "-v" ]]; then
  printf "v%s\n" "$SCRIPT_VERSION"
  exit 0
fi

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
  warn "检测到非 root 用户"
  warn "某些功能需要 root 权限，建议使用 sudo 运行"
  pause
fi

# 进入主菜单
main_menu
