#!/usr/bin/env bash
# AstrBot / NapCat 一键部署与管理脚本
# 项目地址:https://github.com/railgun19457/AstrbotScript
# 容器加速配置脚本来源: https://linuxmirrors.cn

set -euo pipefail

SCRIPT_VERSION="2.1.1"

# ==================== 错误代码常量 ====================
readonly ERR_SUCCESS=0
readonly ERR_USER_INPUT=1
readonly ERR_SYSTEM=2

# ==================== 配置文件加载 ====================
# 获取脚本所在的目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/AstrbotScript.conf"

# 默认配置
BASE_DIR="/opt/AstrBot"           # 服务安装根目录
NETWORK_NAME="astrbot"            # Docker 网络名称
COMPOSE_FILENAME="compose.yml"    # Compose 文件名
ASTRBOT_PORT="6185:6185"          # AstrBot 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)
NAPCAT_PORT="6099:6099"           # NapCat 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)

# 支持的服务列表
readonly ALL_SERVICES=("astrbot" "napcat")

# 如果配置文件存在则读取
if [[ -f "$CONFIG_FILE" ]]; then
  # 注意：只读取合法的变量名，忽略注释和空行
  source <(grep -E "^(BASE_DIR|NETWORK_NAME|ASTRBOT_PORT|NAPCAT_PORT)=" "$CONFIG_FILE")
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

# ==================== 端口配置 ====================
# AstrBot 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)
# 示例: ASTRBOT_PORT="6185:6185,8080:8080"
ASTRBOT_PORT="6185:6185"

# NapCat 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)
# 示例: NAPCAT_PORT="6099:6099,3000:3000"
NAPCAT_PORT="6099:6099"
EOF
fi

# 如果使用 --no-color 或环境变量 NO_COLOR，则禁用彩色输出
if [[ "${1:-}" == "--no-color" ]]; then NO_COLOR=1; shift; fi
if [[ -n "${NO_COLOR:-}" ]]; then
  C_RESET=""; C_BOLD=""; C_DIM=""; C_UNDERLINE="";
  C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_MAGENTA=""; C_CYAN=""; C_WHITE="";
  C_BRIGHT_RED=""; C_BRIGHT_GREEN=""; C_BRIGHT_YELLOW=""; C_BRIGHT_BLUE=""; C_BRIGHT_MAGENTA=""; C_BRIGHT_CYAN=""; C_BRIGHT_WHITE="";
else
  # ==================== 颜色定义 ====================
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'; C_UNDERLINE=$'\033[4m'
  C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_BLUE=$'\033[34m'; C_MAGENTA=$'\033[35m'; C_CYAN=$'\033[36m'; C_WHITE=$'\033[37m'
  C_BRIGHT_RED=$'\033[91m'; C_BRIGHT_GREEN=$'\033[92m'; C_BRIGHT_YELLOW=$'\033[93m'; C_BRIGHT_BLUE=$'\033[94m'; C_BRIGHT_MAGENTA=$'\033[95m'; C_BRIGHT_CYAN=$'\033[96m'; C_BRIGHT_WHITE=$'\033[97m'
fi

# ==================== 日志函数 ====================
info()    { printf "%s\n" "${C_GREEN}[INFO]${C_RESET} $*" >&2; }
warn()    { printf "%s\n" "${C_YELLOW}[WARN]${C_RESET} $*" >&2; }
err()     { printf "%s\n" "${C_RED}[ERROR]${C_RESET} $*" >&2; }
success() { printf "%s\n" "${C_BRIGHT_GREEN}${C_BOLD}[SUCCESS]${C_RESET} $*" >&2; }
debug()   { [[ -n "${DEBUG_LOG:-}" ]] && printf "%s\n" "${C_BRIGHT_CYAN}[DEBUG]${C_RESET} $*" >&2; }

# ==================== 工具函数 ====================
require_root(){
  if [[ $EUID -ne 0 ]]; then
    err "需要 root 权限执行 (sudo)。"
    return $ERR_USER_INPUT
  fi
  return $ERR_SUCCESS
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

# ==================== Layer 1: 核心工具函数扩展 ====================

# 确保文件存在
ensure_file_exists(){
  local file="$1"
  if [[ ! -f "$file" ]]; then
    err "文件不存在: $file"
    return $ERR_USER_INPUT
  fi
  return $ERR_SUCCESS
}

# 显示标题头
print_header(){
  local title="$1"
  local width=70
  echo "${C_BRIGHT_CYAN}$(printf '━%.0s' $(seq 1 $width))${C_RESET}"
  printf "${C_BRIGHT_BLUE}${C_BOLD}%*s${C_RESET}\n" $(((${#title}+$width)/2)) "$title"
  echo "${C_BRIGHT_CYAN}$(printf '━%.0s' $(seq 1 $width))${C_RESET}"
}

# 显示分隔线
print_separator(){
  local width="${1:-70}"
  echo "${C_BRIGHT_CYAN}$(printf '━%.0s' $(seq 1 $width))${C_RESET}"
}

# 显示键值对
print_key_value(){
  local key="$1" value="$2"
  printf "  ${C_CYAN}%s:${C_RESET} ${C_BRIGHT_WHITE}%s${C_RESET}\n" "$key" "$value"
}

# 通用用户输入提示
prompt_user(){
  local prompt="$1"
  local default="${2:-}"
  local input=""

  if [[ -n "$default" ]]; then
    read -r -p "${C_BRIGHT_BLUE}${prompt} [${default}]:${C_RESET} " input || true
    echo "${input:-$default}"
  else
    read -r -p "${C_BRIGHT_BLUE}${prompt}:${C_RESET} " input || true
    echo "$input"
  fi
}

# 密码输入提示（带确认）
prompt_password(){
  local prompt="$1"
  local password=""
  read -r -s -p "${C_BRIGHT_BLUE}${prompt}:${C_RESET} " password || true
  echo "" >&2
  echo "$password"
}

# 菜单选择提示
prompt_choice(){
  local prompt="$1"
  local choice=""
  read -r -p "${C_BRIGHT_BLUE}${prompt}:${C_RESET} " choice || true
  echo "$choice"
}

# ==================== Layer 2: 配置管理函数 ====================

# 显示端口格式帮助信息
show_port_format_help(){
  cat <<EOF

${C_BRIGHT_YELLOW}端口映射格式说明:${C_RESET}
  ${C_GREEN}•${C_RESET} 单个端口: ${C_BRIGHT_WHITE}宿主机端口:容器端口${C_RESET}
    示例: ${C_CYAN}6185:6185${C_RESET}
  ${C_GREEN}•${C_RESET} 多个端口: 用逗号分隔
    示例: ${C_CYAN}6185:6185,8080:8080,9000:9000${C_RESET}
  ${C_GREEN}•${C_RESET} 留空: 不映射端口
  ${C_GREEN}•${C_RESET} 输入 ${C_CYAN}q${C_RESET}: 保持当前配置不变

EOF
}

# 重新生成 compose 文件（如果存在）
regenerate_compose_if_exists(){
  if [[ ! -f "$BASE_DIR/$COMPOSE_FILENAME" ]]; then
    return $ERR_SUCCESS
  fi

  info "正在重新生成 compose 文件..."
  if generate_full_compose "$BASE_DIR/$COMPOSE_FILENAME"; then
    success "✓ compose 文件已更新"
    warn "注意: 需要重新部署服务才能生效"
    return $ERR_SUCCESS
  else
    err "compose 文件生成失败"
    return $ERR_SYSTEM
  fi
}

# 通用设置更新函数
update_setting(){
  local var_name="$1"
  local display_name="$2"
  local current_value="${!var_name}"

  clear_screen
  echo "${C_CYAN}当前${display_name}: ${C_BRIGHT_WHITE}$current_value${C_RESET}"

  local new_value
  new_value=$(prompt_user "请输入新的${display_name} (留空保持不变)")

  if [[ -z "$new_value" ]]; then
    info "${display_name}保持不变"
    pause
    return $ERR_SUCCESS
  fi

  printf -v "$var_name" "%s" "$new_value"
  save_config
  success "${display_name}已更新为: $new_value"
  info "配置已保存到: $CONFIG_FILE"
  pause
  return $ERR_SUCCESS
}

# 通用端口设置更新函数（消除 AstrBot 和 NapCat 的重复代码）
update_port_setting(){
  local service="$1"
  local port_var="${service^^}_PORT"  # 转换为大写: astrbot -> ASTRBOT_PORT
  local current_port="${!port_var}"
  local current_port_display="$current_port"
  [[ -z "$current_port_display" ]] && current_port_display="(不映射端口)"

  clear_screen
  echo "${C_CYAN}当前 ${service} 端口映射: ${C_BRIGHT_WHITE}$current_port_display${C_RESET}"
  show_port_format_help

  local new_port
  new_port=$(prompt_user "请输入新的端口映射 (直接回车=不映射，q=保持不变)")

  # q / Q: 保持不变
  if [[ "$new_port" =~ ^[Qq]$ ]]; then
    info "端口映射保持不变"
    pause
    return $ERR_SUCCESS
  fi

  # 移除空格
  new_port="${new_port// /}"

  if [[ -z "$new_port" ]]; then
    printf -v "$port_var" "%s" ""
    save_config
    success "${service} 端口映射已更新为: (不映射端口)"
    info "配置已保存到: $CONFIG_FILE"

    # 如果 compose 文件存在，重新生成
    regenerate_compose_if_exists

    pause
    return $ERR_SUCCESS
  fi

  if ! validate_port_mapping "$new_port"; then
    err "无效的端口映射格式"
    err "格式: 宿主机端口:容器端口 或 端口1:端口1,端口2:端口2"
    err "端口范围: 1-65535"
    pause
    return $ERR_USER_INPUT
  fi

  printf -v "$port_var" "%s" "$new_port"
  save_config
  success "${service} 端口映射已更新为: $new_port"
  info "配置已保存到: $CONFIG_FILE"

  # 如果 compose 文件存在，重新生成
  regenerate_compose_if_exists

  pause
  return $ERR_SUCCESS
}

# ==================== Layer 3: JSON 操作抽象层 ====================

# 读取 JSON 字段值
json_read_field(){
  local file="$1"
  local field_path="$2"

  if [[ ! -f "$file" ]]; then
    echo ""
    return $ERR_USER_INPUT
  fi

  if has_cmd jq; then
    jq -r ".$field_path // \"\"" "$file" 2>/dev/null || echo ""
  else
    # 提取字段名（从路径中获取最后一部分）
    local field_name="${field_path##*.}"
    grep -o "\"${field_name}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" "$file" 2>/dev/null | \
      sed "s/.*\"${field_name}\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/" || echo ""
  fi
}

# 写入 JSON 字段值
json_write_field(){
  local file="$1"
  local field_path="$2"
  local new_value="$3"

  if [[ ! -f "$file" ]]; then
    err "文件不存在: $file"
    return $ERR_USER_INPUT
  fi

  if has_cmd jq; then
    if jq ".$field_path = \"$new_value\"" "$file" > "${file}.tmp" 2>/dev/null; then
      mv "${file}.tmp" "$file"
      return $ERR_SUCCESS
    else
      rm -f "${file}.tmp"
      err "JSON 更新失败"
      return $ERR_SYSTEM
    fi
  else
    # 提取字段名（从路径中获取最后一部分）
    local field_name="${field_path##*.}"
    if sed -i.bak "s/\"${field_name}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"${field_name}\": \"$new_value\"/" "$file" 2>/dev/null; then
      rm -f "${file}.bak"
      return $ERR_SUCCESS
    else
      err "JSON 更新失败"
      return $ERR_SYSTEM
    fi
  fi
}

# ==================== Docker 检测与安装 ====================
detect_compose_cmd(){ docker compose version >/dev/null 2>&1 && echo "docker compose" && return || has_cmd docker-compose && echo "docker-compose" || echo ""; }

check_docker_installed(){ has_cmd docker; }

install_docker(){
  require_root || { warn "安装 Docker 需要 root 权限"; pause; return $ERR_SYSTEM; }
  info "安装 Docker 环境 (含镜像加速) ..."
  local downloader="" temp_script="/tmp/docker_install_$$.sh"
  has_cmd curl && downloader="curl -fsSL" || has_cmd wget && downloader="wget -qO-" || { err "缺少 curl / wget"; pause; return $ERR_SYSTEM; }
  info "正在下载安装脚本..."
  if ! $downloader https://linuxmirrors.cn/docker.sh > "$temp_script"; then err "下载安装脚本失败"; rm -f "$temp_script"; pause; return $ERR_SYSTEM; fi
  chmod +x "$temp_script"
  info "开始执行安装脚本..."
  if ! bash "$temp_script"; then err "执行安装脚本失败"; rm -f "$temp_script"; pause; return $ERR_SYSTEM; fi
  rm -f "$temp_script"
  check_docker_installed || { err "Docker 未正确安装"; pause; return $ERR_SYSTEM; }
  [[ -z "$(detect_compose_cmd)" ]] && warn "未检测到 Compose，可能需要手动安装" || info "Compose 已检测"
  success "Docker 安装完成"
  pause
}

# ==================== Layer 4: Docker 操作辅助函数 ====================

# 检查容器是否存在
container_exists(){
  local container="$1"
  docker ps -a --filter "name=^${container}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"
}

# 检查容器是否运行中
container_running(){
  local container="$1"
  docker ps --filter "name=^${container}$" --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"
}

# 获取容器信息
container_get_info(){
  local container="$1"
  local format="$2"
  local default="${3:--}"
  docker inspect "$container" --format "$format" 2>/dev/null || echo "$default"
}

# 格式化端口显示
get_formatted_ports(){
  local service="$1"
  local ports
  ports=$(docker ps --filter "name=^${service}$" --format '{{.Ports}}' 2>/dev/null | \
    tr ',' '\n' | \
    grep -v "\[::\]" | \
    sed 's/0\.0\.0\.0://g' | \
    sed 's/^[ \t]*//' | \
    tr '\n' ',' | \
    sed 's/,$//' || echo '-')

  [[ -z "$ports" || "$ports" == " " ]] && ports="-"
  echo "$ports"
}

# 启动服务依赖
start_dependencies(){
  local service="$1"
  local deps
  deps=$(service_dependencies "$service")

  [[ -z "$deps" ]] && return $ERR_SUCCESS

  for dep in $deps; do
    if container_exists "$dep"; then
      docker start "$dep" >/dev/null 2>&1 || \
      docker restart "$dep" >/dev/null 2>&1 || true
    fi
  done

  return $ERR_SUCCESS
}

# 检查镜像更新
check_image_update(){
  local base="$1"
  local service="$2"

  local current_digest
  current_digest=$(docker inspect "$service" --format='{{.Image}}' 2>/dev/null || echo "")

  info "正在拉取最新镜像..."
  if ! compose_exec "$base" pull "$service"; then
    err "拉取镜像失败"
    return $ERR_SYSTEM
  fi

  local image_name
  image_name=$(docker inspect "$service" --format='{{.Config.Image}}' 2>/dev/null || echo "")

  local new_digest=""
  if [[ -n "$image_name" ]]; then
    new_digest=$(docker images --no-trunc --quiet "$image_name" 2>/dev/null | head -1 || echo "")
  fi

  # 返回是否有更新 (0=有更新, 1=无更新)
  if [[ -n "$current_digest" && -n "$new_digest" && "$current_digest" == "$new_digest" ]]; then
    return 1  # 无更新
  else
    return 0  # 有更新
  fi
}

# ==================== 网络与目录初始化 ====================
# 初始化 Docker 网络
init_network(){
  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    info "正在创建 Docker 网络: $NETWORK_NAME"
    if ! docker network create --driver bridge "$NETWORK_NAME" >/dev/null 2>&1; then
      err "创建网络失败，请检查 Docker 是否运行"
      return $ERR_SYSTEM
    fi
    info "✓ 网络创建成功"
  else
    info "✓ 使用已存在的网络: $NETWORK_NAME"
  fi
  return $ERR_SUCCESS
}

# 初始化安装目录
init_base_dir(){
  if ! mkdir -p -- "$BASE_DIR" 2>/dev/null; then
    err "无法创建目录: $BASE_DIR"
    return $ERR_SYSTEM
  fi
  info "✓ 安装根目录: $BASE_DIR"
  return $ERR_SUCCESS
}

ensure_dirs(){ local base="$1"; shift; for d in "$@"; do mkdir -p -- "$base/$d" || { err "无法创建目录: $base/$d"; return 1; }; done; }

# ==================== 服务配置生成 ====================

# ==================== Compose 文件生成 ====================
# 生成完整的 compose.yml（包含所有服务定义）
generate_full_compose(){
  local outfile="$1"

  # 生成端口映射的 YAML 格式
  generate_port_yaml() {
    local ports="$1"
    local indent="$2"
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    for port in "${PORT_ARRAY[@]}"; do
      echo "${indent}- \"${port}\""
    done
  }

  # 生成随机 MAC 地址（Docker 兼容格式）
  generate_random_mac() {
    printf "02:42:%02x:%02x:%02x:%02x" $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256))
  }

  # 生成 AstrBot 端口配置
  local astrbot_ports_block=""
  if [[ -n "${ASTRBOT_PORT// /}" ]]; then
    local astrbot_ports
    astrbot_ports=$(generate_port_yaml "$ASTRBOT_PORT" "      ")
    astrbot_ports_block=$(cat <<EOF
    ports:
$astrbot_ports
EOF
)
  fi

  # 生成 NapCat 端口配置
  local napcat_ports_block=""
  if [[ -n "${NAPCAT_PORT// /}" ]]; then
    local napcat_ports
    napcat_ports=$(generate_port_yaml "$NAPCAT_PORT" "      ")
    napcat_ports_block=$(cat <<EOF
    ports:
$napcat_ports
EOF
)
  fi

  # 生成随机 MAC 地址
  local random_mac
  random_mac=$(generate_random_mac)

  cat >"$outfile" <<COMPOSE_EOF
services:
  astrbot:
    image: soulter/astrbot:latest
    container_name: astrbot
    restart: unless-stopped
    environment:
      - TZ=Asia/Shanghai
$astrbot_ports_block
    volumes:
      - ./astrbot/data:/AstrBot/data
      - /var/run/docker.sock:/var/run/docker.sock
    networks:
      - astrbot

  napcat:
    image: mlikiowa/napcat-docker:latest
    container_name: napcat
    restart: unless-stopped
    environment:
      - NAPCAT_UID=\${NAPCAT_UID:-1000}
      - NAPCAT_GID=\${NAPCAT_GID:-1000}
      - MODE=astrbot
$napcat_ports_block
    volumes:
      - ./astrbot/data:/AstrBot/data
      - ./napcat/ntqq:/app/.config/QQ
      - ./napcat/config:/app/napcat/config
    networks:
      - astrbot
    mac_address: "$random_mac"

networks:
  astrbot:
    external: true
    name: $NETWORK_NAME
COMPOSE_EOF

  info "✓ 已生成完整的 compose 文件: $outfile"
}

# ==================== 服务检测与管理 ====================

# ==================== Layer 5: 服务管理辅助函数 ====================

# 获取服务状态信息（返回键值对格式）
get_service_status(){
  local service="$1"

  # 默认状态
  echo "name=$service"
  echo "icon=⚠️  未安装"
  echo "ip=-"
  echo "image=-"
  echo "ports=-"

  # 检查容器是否存在
  if ! container_exists "$service"; then
    return $ERR_SUCCESS
  fi

  # 容器存在，检查是否运行中
  if container_running "$service"; then
    echo "icon=✅ 运行中"
    echo "ip=$(container_get_info "$service" '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' '-')"
    echo "image=$(container_get_info "$service" '{{.Config.Image}}' '-')"
    echo "ports=$(get_formatted_ports "$service")"
  else
    echo "icon=❌ 未运行"
    echo "image=$(docker ps -a --filter "name=^${service}$" --format '{{.Image}}' 2>/dev/null || echo '-')"
  fi

  return $ERR_SUCCESS
}

# 解析服务状态到关联数组
parse_service_status(){
  local service="$1"
  local -n status_ref="$2"

  while IFS== read -r key value; do
    status_ref[$key]="$value"
  done < <(get_service_status "$service")
}

# 重新生成 compose 文件（包含新的随机 MAC 地址）
regenerate_compose_with_new_mac(){
  local base="$1"

  if [[ ! -f "$base/$COMPOSE_FILENAME" ]]; then
    return $ERR_SUCCESS
  fi

  info "正在重新生成 compose 文件..."
  if generate_full_compose "$base/$COMPOSE_FILENAME"; then
    success "✓ compose 文件已更新（包含新的随机 MAC 地址）"
    return $ERR_SUCCESS
  else
    warn "compose 文件生成失败，继续使用现有配置"
    return $ERR_SYSTEM
  fi
}

# 启动服务
service_start(){
  local base="$1"
  local service="$2"

  info "启动 $service ..."
  start_dependencies "$service"

  if compose_exec "$base" up -d "$service" 2>/dev/null; then
    success "$service 启动成功"
    return $ERR_SUCCESS
  elif docker start "$service" 2>/dev/null; then
    success "$service 启动成功"
    return $ERR_SUCCESS
  else
    err "$service 启动失败"
    return $ERR_SYSTEM
  fi
}

# 停止服务
service_stop(){
  local base="$1"
  local service="$2"

  info "停止 $service ..."

  if compose_exec "$base" stop "$service" 2>/dev/null; then
    success "$service 停止成功"
  elif docker stop "$service" 2>/dev/null; then
    success "$service 停止成功"
  else
    warn "容器不存在或已停止"
  fi

  # 停止依赖
  local deps
  deps=$(service_dependencies "$service")
  if [[ -n "$deps" ]]; then
    for d in $deps; do
      docker stop "$d" 2>/dev/null || true
    done
  fi

  return $ERR_SUCCESS
}

# 重启服务
service_restart(){
  local base="$1"
  local service="$2"

  info "重启 $service ..."
  start_dependencies "$service"

  if compose_exec "$base" restart "$service" 2>/dev/null; then
    success "$service 重启成功"
    return $ERR_SUCCESS
  elif docker restart "$service" 2>/dev/null; then
    success "$service 重启成功"
    return $ERR_SUCCESS
  else
    err "$service 重启失败"
    return $ERR_SYSTEM
  fi
}

# 重建服务（更新镜像）
service_rebuild(){
  local base="$1"
  local service="$2"
  local compose_file="$base/$COMPOSE_FILENAME"

  # 计算旧 compose 文件的哈希值（如果存在）
  local old_hash=""
  if [[ -f "$compose_file" ]]; then
    if has_cmd md5sum; then
      old_hash=$(md5sum "$compose_file" 2>/dev/null | awk '{print $1}')
    elif has_cmd md5; then
      old_hash=$(md5 -q "$compose_file" 2>/dev/null)
    fi
  fi

  # 重新生成 compose 文件
  regenerate_compose_with_new_mac "$base"

  # 计算新 compose 文件的哈希值
  local new_hash=""
  if [[ -f "$compose_file" ]]; then
    if has_cmd md5sum; then
      new_hash=$(md5sum "$compose_file" 2>/dev/null | awk '{print $1}')
    elif has_cmd md5; then
      new_hash=$(md5 -q "$compose_file" 2>/dev/null)
    fi
  fi

  # 检查 compose 文件是否有变化
  local compose_changed=false
  if [[ -n "$old_hash" && -n "$new_hash" && "$old_hash" != "$new_hash" ]]; then
    compose_changed=true
  fi

  info "正在检查 $service 镜像更新..."

  # 使用新的 check_image_update 函数
  local image_updated=false
  if check_image_update "$base" "$service"; then
    image_updated=true
  fi

  # 判断是否需要重建
  if [[ "$image_updated" == true || "$compose_changed" == true ]]; then
    # 显示重建原因
    if [[ "$image_updated" == true && "$compose_changed" == true ]]; then
      info "检测到镜像更新和配置变化，正在重建容器..."
    elif [[ "$image_updated" == true ]]; then
      info "检测到镜像更新，正在重建容器..."
    else
      info "检测到配置变化，正在重建容器..."
    fi

    if compose_exec "$base" up -d "$service"; then
      success "容器已重建完成"
      return $ERR_SUCCESS
    else
      err "重建容器失败"
      return $ERR_SYSTEM
    fi
  else
    # 无更新
    info "镜像和配置均无变化，无需重建"
    return $ERR_SUCCESS
  fi
}

# 删除服务
service_delete(){
  local service="$1"

  if docker rm -fv "$service" 2>/dev/null; then
    success "$service 删除成功"
    return $ERR_SUCCESS
  else
    warn "容器不存在"
    return $ERR_USER_INPUT
  fi
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

# ==================== 端口配置 ====================
# AstrBot 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)
# 示例: ASTRBOT_PORT="6185:6185,8080:8080"
ASTRBOT_PORT="$ASTRBOT_PORT"

# NapCat 端口映射 (格式: 宿主机端口:容器端口,可用逗号分隔多个)
# 示例: NAPCAT_PORT="6099:6099,3000:3000"
NAPCAT_PORT="$NAPCAT_PORT"
EOF
}

# 验证端口映射格式
validate_port_mapping(){
  local port_str="$1"
  # 移除空格
  port_str="${port_str// /}"

  # 允许空值（表示不映射端口）
  [[ -z "$port_str" ]] && return 0

  # 分割多个端口映射
  IFS=',' read -ra PORT_ARRAY <<< "$port_str"

  for mapping in "${PORT_ARRAY[@]}"; do
    # 检查格式是否为 数字:数字
    if [[ ! "$mapping" =~ ^[0-9]+:[0-9]+$ ]]; then
      return 1
    fi

    # 提取宿主机端口和容器端口
    local host_port="${mapping%%:*}"
    local container_port="${mapping##*:}"

    # 验证端口范围
    if (( host_port < 1 || host_port > 65535 || container_port < 1 || container_port > 65535 )); then
      return 1
    fi
  done

  return 0
}

# ==================== 设置菜单 ====================
# ==================== Layer 7: UI 层 - 设置菜单 ====================
menu_settings(){
  while true; do
    clear_screen

    local astrbot_port_display="$ASTRBOT_PORT"
    local napcat_port_display="$NAPCAT_PORT"
    [[ -z "$astrbot_port_display" ]] && astrbot_port_display="(不映射端口)"
    [[ -z "$napcat_port_display" ]] && napcat_port_display="(不映射端口)"

    cat <<EOF
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}                    安装设置${C_RESET}
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}当前配置:${C_RESET}
  ${C_CYAN}📁 安装目录:${C_RESET}     ${C_BRIGHT_WHITE}$BASE_DIR${C_RESET}
  ${C_CYAN}🌐 网络名称:${C_RESET}     ${C_BRIGHT_WHITE}$NETWORK_NAME${C_RESET}
  ${C_CYAN}🔌 AstrBot端口:${C_RESET}  ${C_BRIGHT_WHITE}$astrbot_port_display${C_RESET}
  ${C_CYAN}🔌 NapCat端口:${C_RESET}   ${C_BRIGHT_WHITE}$napcat_port_display${C_RESET}

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}修改选项:${C_RESET}
  ${C_GREEN}1)${C_RESET} 修改安装目录
  ${C_GREEN}2)${C_RESET} 修改网络名称
  ${C_GREEN}3)${C_RESET} 修改 AstrBot 端口
  ${C_GREEN}4)${C_RESET} 修改 NapCat 端口

  ${C_BRIGHT_RED}0)${C_RESET} 返回主菜单

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    local choice
    choice=$(prompt_choice "请选择 (0-4)")

    case "$choice" in
      1) update_setting "BASE_DIR" "安装目录" || true ;;
      2) update_setting "NETWORK_NAME" "网络名称" || true ;;
      3) update_port_setting "astrbot" || true ;;
      4) update_port_setting "napcat" || true ;;
      0) return 0 ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 服务选择菜单 ====================
menu_install_services(){
  local selected_astrbot=0 selected_napcat=0

  while true; do
    clear_screen

    local astrbot_mark="[ ]" napcat_mark="[ ]"
    [[ $selected_astrbot -eq 1 ]] && astrbot_mark="${C_BRIGHT_GREEN}[✓]${C_RESET}"
    [[ $selected_napcat -eq 1 ]] && napcat_mark="${C_BRIGHT_GREEN}[✓]${C_RESET}"

    cat <<EOF
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}          选择需要部署的服务${C_RESET}
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${astrbot_mark} ${C_GREEN}1)${C_RESET} ${C_BRIGHT_WHITE}AstrBot${C_RESET}
${napcat_mark} ${C_GREEN}2)${C_RESET} ${C_BRIGHT_WHITE}NapCat${C_RESET}

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_GREEN}3)${C_RESET} 开始安装
${C_BRIGHT_RED}0)${C_RESET} 返回主菜单
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-3):${C_RESET} " opt || true
    case "$opt" in
      1) selected_astrbot=$((1-selected_astrbot)) ;;
      2) selected_napcat=$((1-selected_napcat)) ;;
      3)
        if (( !selected_astrbot && !selected_napcat )); then
          warn "❌ 请至少选择一个服务"
          pause
          continue
        fi

        # 生成服务类型列表
        local service_types=()
        (( selected_astrbot )) && service_types+=("astrbot")
        (( selected_napcat )) && service_types+=("napcat")

        # 调用安装函数，传递所有选中的服务
        install_service_begin "${service_types[@]}"
        return 0
        ;;
      0) return 0 ;;
      *) warn "❌ 无效选择" && sleep 1 ;;
    esac
  done
}

install_service_begin(){
  local -a service_types=("$@"); require_root || { warn "需要 root"; pause; return 1; }
  [[ -z "$(detect_compose_cmd)" ]] && { warn "未检测到 Compose，尝试安装 Docker"; install_docker || { err "Docker 安装失败"; pause; return 1; }; }
  init_network || { pause; return 1; }; init_base_dir || { pause; return 1; }
  [[ ${#service_types[@]} -eq 0 ]] && { err "未选择服务"; pause; return 1; }
  info "准备部署: ${service_types[*]}"
  for svc_type in "${service_types[@]}"; do
    case "$svc_type" in
      astrbot)      ensure_dirs "$BASE_DIR/astrbot" data || return 1 ;;
      napcat)       ensure_dirs "$BASE_DIR/napcat" ntqq config || return 1 ;;
    esac
  done
  generate_full_compose "$BASE_DIR/$COMPOSE_FILENAME" || return 1
  local cmd="cd '$BASE_DIR' && $(detect_compose_cmd) up -d ${service_types[*]}"
  if eval "$cmd"; then success "部署完成"; info "目录: $BASE_DIR 网络: $NETWORK_NAME"; else err "部署失败"; pause; return 1; fi
  pause
}

# ==================== Compose 命令执行 ====================
compose_exec(){ local dir="$1"; shift; local compose_cmd="$(detect_compose_cmd)"; [[ -z "$compose_cmd" ]] && { err "缺少 compose"; return 2; }; local cmd="cd '$dir' && $compose_cmd $*"; eval "$cmd"; }

# ==================== 统一服务依赖与操作 ====================
# 服务依赖关系（预留接口，当前无依赖）
# 返回: 空格分隔的依赖服务名称列表
service_dependencies(){ echo ""; }

# 服务操作调度器（简化版）
service_action(){
  local action="$1"
  local base="$2"
  local service="$3"

  case "$action" in
    start)   service_start "$base" "$service" ;;
    stop)    service_stop "$base" "$service" ;;
    restart) service_restart "$base" "$service" ;;
    rebuild) service_rebuild "$base" "$service" ;;
    delete)  service_delete "$service" ;;
    *)       err "未知操作: $action"; return $ERR_USER_INPUT ;;
  esac
}

# ==================== 服务操作包装函数 ====================
start_service(){ service_start "$1" "$2"; pause; }
stop_service(){ service_stop "$1" "$2"; pause; }
restart_service(){ service_restart "$1" "$2"; pause; }
show_service_logs(){
  local base="$1" service_name="$2"
  info "正在获取 $service_name 服务的日志（按 Ctrl+C 退出）..."
  docker logs -f --tail 100 "$service_name" 2>/dev/null || err "无法获取日志 - 容器不存在"
}
rebuild_service(){ local base="$1" service_name="$2"; warn "这会拉取最新镜像并重建容器 $service_name"; read -r -p "确认? (Y/N): " c || true; [[ "$c" =~ ^[Yy]$ ]] || { info "已取消"; pause; return 0; }; service_action rebuild "$base" "$service_name"; pause; }

# ==================== Layer 6: 密码管理框架 ====================

# 获取服务密码配置（服务适配器）
get_service_password_config(){
  local service="$1"

  case "$service" in
    astrbot)
      echo "config_file=astrbot/data/cmd_config.json"
      echo "username_field=dashboard.username"
      echo "password_field=dashboard.password"
      echo "password_type=md5"
      echo "display_name=AstrBot"
      echo "has_username=true"
      ;;
    napcat)
      echo "config_file=napcat/config/webui.json"
      echo "username_field="
      echo "password_field=token"
      echo "password_type=plain"
      echo "display_name=NapCat"
      echo "has_username=false"
      ;;
    *)
      err "不支持的服务: $service"
      return $ERR_USER_INPUT
      ;;
  esac

  return $ERR_SUCCESS
}

# 显示密码管理菜单
show_password_menu(){
  local service="$1"
  local config_file="$2"
  local -n config_ref="$3"

  clear_screen
  print_header "${config_ref[display_name]} 密码管理"

  echo ""
  echo "${C_BRIGHT_YELLOW}当前账号信息:${C_RESET}"

  # 显示用户名（如果有）
  if [[ "${config_ref[has_username]}" == "true" ]]; then
    local current_username
    current_username=$(json_read_field "$config_file" "${config_ref[username_field]}")
    [[ -z "$current_username" ]] && current_username="未设置"
    print_key_value "用户名" "$current_username"
  fi

  # 显示密码信息
  if [[ "${config_ref[password_type]}" == "plain" ]]; then
    local current_password
    current_password=$(json_read_field "$config_file" "${config_ref[password_field]}")
    [[ -z "$current_password" ]] && current_password="未设置"
    print_key_value "密码 (Token)" "$current_password"
    echo "  ${C_DIM}注意: ${config_ref[display_name]} 使用明文存储密码${C_RESET}"
  else
    print_key_value "密码" "${C_DIM}(已加密，无法直接查看)${C_RESET}"
  fi

  echo ""
  print_separator
  echo ""
  echo "${C_BRIGHT_YELLOW}操作选项:${C_RESET}"

  if [[ "${config_ref[has_username]}" == "true" ]]; then
    echo "  ${C_GREEN}1)${C_RESET} 修改用户名"
    echo "  ${C_GREEN}2)${C_RESET} 修改密码"
    echo "  ${C_BRIGHT_RED}0)${C_RESET} 返回上级菜单"
  else
    echo "  ${C_GREEN}1)${C_RESET} 修改密码"
    echo "  ${C_BRIGHT_RED}0)${C_RESET} 返回上级菜单"
  fi

  echo ""
  print_separator
}

# 更新用户名
update_username(){
  local config_file="$1"
  local username_field="$2"

  local new_username
  new_username=$(prompt_user "请输入新的用户名")

  if [[ -z "$new_username" ]]; then
    warn "用户名不能为空"
    pause
    return $ERR_USER_INPUT
  fi

  if json_write_field "$config_file" "$username_field" "$new_username"; then
    success "用户名已更新为: $new_username"
    info "请重启服务使更改生效"
    pause
    return $ERR_SUCCESS
  else
    pause
    return $ERR_SYSTEM
  fi
}

# 更新密码
update_password(){
  local config_file="$1"
  local password_field="$2"
  local password_type="$3"

  local new_password
  new_password=$(prompt_password "请输入新密码(不显示)")

  if [[ -z "$new_password" ]]; then
    warn "密码不能为空"
    pause
    return $ERR_USER_INPUT
  fi

  local confirm_password
  confirm_password=$(prompt_password "请再次输入新密码")

  if [[ "$new_password" != "$confirm_password" ]]; then
    err "两次输入的密码不一致"
    pause
    return $ERR_USER_INPUT
  fi

  # 根据类型处理密码
  local final_password="$new_password"
  if [[ "$password_type" == "md5" ]]; then
    final_password=$(generate_md5 "$new_password")
    if [[ $? -ne 0 ]]; then
      pause
      return $ERR_SYSTEM
    fi
  fi

  if json_write_field "$config_file" "$password_field" "$final_password"; then
    success "密码已更新"
    info "请重启服务使更改生效"
    pause
    return $ERR_SUCCESS
  else
    pause
    return $ERR_SYSTEM
  fi
}

# 通用密码管理函数（替代 manage_astrbot_password 和 manage_napcat_password）
manage_password(){
  local base="$1"
  local service="$2"

  # 加载服务配置
  local -A config
  while IFS== read -r key value; do
    config[$key]="$value"
  done < <(get_service_password_config "$service")

  local config_file="$base/${config[config_file]}"

  # 检查配置文件是否存在
  if ! ensure_file_exists "$config_file"; then
    warn "请确保 ${config[display_name]} 已正确部署并至少运行过一次"
    pause
    return $ERR_USER_INPUT
  fi

  while true; do
    show_password_menu "$service" "$config_file" config

    local choice
    choice=$(prompt_choice "请选择 (0-2)")

    case "$choice" in
      1)
        if [[ "${config[has_username]}" == "true" ]]; then
          update_username "$config_file" "${config[username_field]}"
        else
          update_password "$config_file" "${config[password_field]}" "${config[password_type]}"
        fi
        ;;
      2)
        if [[ "${config[has_username]}" == "true" ]]; then
          update_password "$config_file" "${config[password_field]}" "${config[password_type]}"
        else
          warn "无效选择"
          sleep 1
        fi
        ;;
      0) return $ERR_SUCCESS ;;
      *) warn "无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 密码管理功能 ====================
# MD5 哈希函数
generate_md5(){
  local input="$1"
  if has_cmd md5sum; then
    echo -n "$input" | md5sum | awk '{print $1}'
  elif has_cmd md5; then
    echo -n "$input" | md5 -q
  else
    err "未找到 md5sum 或 md5 命令"
    return 1
  fi
}

# ==================== Compose 文件操作 ====================
delete_service(){
  local base="$1" service_name="$2"; clear_screen; cat <<EOF
${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_RED}${C_BOLD}      ⚠ 删除 ${C_BRIGHT_WHITE}$service_name${C_RESET}${C_BRIGHT_RED} 服务确认${C_RESET}
${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

  ${C_YELLOW}1)${C_RESET} 仅删除容器  ${C_DIM}(保留数据: ${C_BRIGHT_WHITE}$base/$service_name${C_RESET}${C_DIM})${C_RESET}
  ${C_YELLOW}2)${C_RESET} 删除容器与数据  ${C_RED}(不可恢复)${C_RESET}
  ${C_YELLOW}0)${C_RESET} 取消

${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF
  read -r -p "${C_BRIGHT_BLUE}选择 (0-2):${C_RESET} " ch || true
  case "$ch" in
    1) read -r -p "${C_BRIGHT_BLUE}确认? (Y/N):${C_RESET} " c || true; [[ "$c" =~ ^[Yy]$ ]] && service_action delete "$base" "$service_name" && info "保留数据: $base/$service_name" ;;
    2) read -r -p "${C_BRIGHT_RED}${C_BOLD}确认完全删除? (Y/N):${C_RESET} " c || true; [[ "$c" =~ ^[Yy]$ ]] || { info "已取消"; pause; return 0; }; service_action delete "$base" "$service_name"; rm -rf -- "$base/$service_name"; info "${C_RED}数据目录已删除${C_RESET}" ;;
    0) info "已取消" ;;
    *) warn "无效选择" ;;
  esac
  pause
}

# ==================== 服务状态显示 ====================
show_all_services_status(){
  clear_screen

  # 统一分隔线长度和样式 (70个字符)
  local sep="━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  cat <<EOF
${C_BRIGHT_GREEN}${sep}${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}                              📊 服务状态${C_RESET}
${C_BRIGHT_GREEN}${sep}${C_RESET}
EOF

  # 定义所有可能的服务
  local all_services=("${ALL_SERVICES[@]}")

  for svc in "${all_services[@]}"; do
    # 使用 get_service_status 获取服务状态
    local -A status
    parse_service_status "$svc" status

    # 显示服务信息
    echo "${C_BRIGHT_WHITE}服务名称: ${C_CYAN}${status[name]}${C_RESET}"
    echo "${C_BRIGHT_WHITE}当前状态: ${status[icon]}${C_RESET}"
    echo "${C_BRIGHT_WHITE}容器 IP : ${C_MAGENTA}${status[ip]}${C_RESET}"
    echo "${C_BRIGHT_WHITE}镜像名称: ${C_BLUE}${status[image]}${C_RESET}"
    echo "${C_BRIGHT_WHITE}端口映射: ${C_YELLOW}${status[ports]}${C_RESET}"
    echo "${C_BRIGHT_GREEN}${sep}${C_RESET}"
  done

  echo ""
  pause
}

# ==================== 服务子菜单 ====================
menu_service_submenu(){
  local service_name="$1"

  while true; do
    clear_screen

    # 使用 get_service_status 获取服务状态
    local -A status
    parse_service_status "$service_name" status

    cat <<EOF
${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
  ${C_BRIGHT_BLUE}${C_BOLD}⚙️  $service_name 管理菜单${C_RESET}
${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

  ${C_CYAN}服务状态:${C_RESET} ${C_BRIGHT_WHITE}${status[icon]}${C_RESET}
  ${C_CYAN}容器名称:${C_RESET} ${C_BRIGHT_WHITE}$service_name${C_RESET}
  ${C_CYAN}镜像名称:${C_RESET} ${C_BRIGHT_WHITE}${status[image]}${C_RESET}
  ${C_CYAN}容器IP:${C_RESET} ${C_BRIGHT_WHITE}${status[ip]}${C_RESET}
  ${C_CYAN}端口映射:${C_RESET} ${C_BRIGHT_WHITE}${status[ports]}${C_RESET}

${C_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_MAGENTA}  📋 操作选项:${C_RESET}
${C_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

  ${C_GREEN}[1]${C_RESET} 启动服务                 ${C_GREEN}[2]${C_RESET} 停止服务
  ${C_GREEN}[3]${C_RESET} 重启服务                 ${C_GREEN}[4]${C_RESET} 查看日志
  ${C_GREEN}[5]${C_RESET} 升级(更新镜像并重建容器) ${C_GREEN}[6]${C_RESET} 密码管理
  ${C_BRIGHT_RED}[7]${C_RESET} 删除服务
  ${C_BRIGHT_BLUE}[0]${C_RESET} 返回上级菜单

${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-7):${C_RESET} " opt || true

    case "$opt" in
      1) start_service "$BASE_DIR" "$service_name" ;;
      2) stop_service "$BASE_DIR" "$service_name" ;;
      3) restart_service "$BASE_DIR" "$service_name" ;;
      4) show_service_logs "$BASE_DIR" "$service_name" ;;
      5) rebuild_service "$BASE_DIR" "$service_name" ;;
      6) manage_password "$BASE_DIR" "$service_name" ;;
      7) delete_service "$BASE_DIR" "$service_name" ;;
      0) break ;;
      *) warn "无效选择" && sleep 1 ;;
    esac
  done
}

# ==================== 主菜单 ====================
main_menu(){
  while true; do
    clear_screen
    cat <<EOF
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}      AstrBot 集成部署与管理脚本 $SCRIPT_VERSION${C_RESET}
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}📋 环境配置:${C_RESET}
  ${C_GREEN}1)${C_RESET} 安装并配置 Docker 环境
     ${C_DIM}(使用Linuxmirrors脚本)${C_RESET}
  ${C_GREEN}2)${C_RESET} ⚙️  安装设置
     ${C_DIM}(修改安装目录和网络名称)${C_RESET}

${C_BRIGHT_MAGENTA}🚀 服务管理:${C_RESET}
  ${C_GREEN}3)${C_RESET} 部署新服务
  ${C_GREEN}4)${C_RESET} 查看服务状态

${C_BRIGHT_GREEN}⚡ 已部署服务管理:${C_RESET}
  ${C_GREEN}5)${C_RESET} AstrBot
  ${C_GREEN}6)${C_RESET} NapCat

  ${C_BRIGHT_RED}0)${C_RESET} 退出脚本

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-6):${C_RESET} " opt || true

    case "$opt" in
      1) install_docker ;;
      2) menu_settings ;;
      3) menu_install_services ;;
      4) show_all_services_status ;;
      5) menu_service_submenu "astrbot" ;;
      6) menu_service_submenu "napcat" ;;
      0)
        clear_screen
        success "感谢使用，再见！"
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
