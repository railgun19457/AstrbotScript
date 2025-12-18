#!/usr/bin/env bash
# AstrBot / NapCat 一键部署与管理脚本
# 项目地址:https://github.com/railgun19457/AstrbotScript
# 容器配置脚本来源: https://linuxmirrors.cn

set -euo pipefail

SCRIPT_VERSION="2.0.1"

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
detect_compose_cmd(){ docker compose version >/dev/null 2>&1 && echo "docker compose" && return || has_cmd docker-compose && echo "docker-compose" || echo ""; }

check_docker_installed(){ has_cmd docker; }

install_docker(){
  require_root || { warn "安装 Docker 需要 root 权限"; pause; return 1; }
  info "安装 Docker 环境 (含镜像加速) ..."
  local downloader="" temp_script="/tmp/docker_install_$$.sh"
  has_cmd curl && downloader="curl -fsSL" || has_cmd wget && downloader="wget -qO-" || { err "缺少 curl / wget"; pause; return 1; }
  info "正在下载安装脚本..."
  if ! $downloader https://linuxmirrors.cn/docker.sh > "$temp_script"; then err "下载安装脚本失败"; rm -f "$temp_script"; pause; return 1; fi
  chmod +x "$temp_script"
  info "开始执行安装脚本..."
  if ! bash "$temp_script"; then err "执行安装脚本失败"; rm -f "$temp_script"; pause; return 1; fi
  rm -f "$temp_script"
  check_docker_installed || { err "Docker 未正确安装"; pause; return 1; }
  [[ -z "$(detect_compose_cmd)" ]] && warn "未检测到 Compose，可能需要手动安装" || info "Compose 已检测"
  success "Docker 安装完成"
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

  # 生成 AstrBot 端口配置
  local astrbot_ports
  astrbot_ports=$(generate_port_yaml "$ASTRBOT_PORT" "      ")

  # 生成 NapCat 端口配置
  local napcat_ports
  napcat_ports=$(generate_port_yaml "$NAPCAT_PORT" "      ")

  cat >"$outfile" <<COMPOSE_EOF
services:
  astrbot:
    image: soulter/astrbot:latest
    container_name: astrbot
    restart: always
    environment:
      - TZ=Asia/Shanghai
    ports:
$astrbot_ports
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
$napcat_ports
    volumes:
      - ./astrbot/data:/AstrBot/data
      - ./napcat/ntqq:/app/.config/QQ
      - ./napcat/config:/app/napcat/config
    networks:
      - astrbot
    mac_address: "02:42:ac:11:00:02"
    cpus: 1.0
    mem_limit: 1g

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

  # 检查两个主服务容器是否存在（不管是否运行）
  for svc_name in astrbot napcat; do
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

  # 检查是否为空
  [[ -z "$port_str" ]] && return 1

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
menu_settings(){
  while true; do
    clear_screen
    cat <<EOF
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}                    安装设置${C_RESET}
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}当前配置:${C_RESET}
  ${C_CYAN}📁 安装目录:${C_RESET}     ${C_BRIGHT_WHITE}$BASE_DIR${C_RESET}
  ${C_CYAN}🌐 网络名称:${C_RESET}     ${C_BRIGHT_WHITE}$NETWORK_NAME${C_RESET}
  ${C_CYAN}🔌 AstrBot端口:${C_RESET}  ${C_BRIGHT_WHITE}$ASTRBOT_PORT${C_RESET}
  ${C_CYAN}🔌 NapCat端口:${C_RESET}   ${C_BRIGHT_WHITE}$NAPCAT_PORT${C_RESET}

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}修改选项:${C_RESET}
  ${C_GREEN}1)${C_RESET} 修改安装目录
  ${C_GREEN}2)${C_RESET} 修改网络名称
  ${C_GREEN}3)${C_RESET} 修改 AstrBot 端口
  ${C_GREEN}4)${C_RESET} 修改 NapCat 端口

  ${C_BRIGHT_RED}0)${C_RESET} 返回主菜单

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-4):${C_RESET} " opt || true

    case "$opt" in
      1)
        clear_screen
        echo "${C_CYAN}当前安装目录: ${C_BRIGHT_WHITE}$BASE_DIR${C_RESET}"
        read -r -p "${C_BRIGHT_BLUE}请输入新的安装目录 (留空保持不变):${C_RESET} " new_base || true
        if [[ -n "$new_base" ]]; then
          BASE_DIR="$new_base"
          save_config
          success "安装目录已更新为: $BASE_DIR"
          info "配置已保存到: $CONFIG_FILE"
        else
          info "安装目录保持不变"
        fi
        pause
        ;;
      2)
        clear_screen
        echo "${C_CYAN}当前网络名称: ${C_BRIGHT_WHITE}$NETWORK_NAME${C_RESET}"
        read -r -p "${C_BRIGHT_BLUE}请输入新的网络名称 (留空保持不变):${C_RESET} " new_network || true
        if [[ -n "$new_network" ]]; then
          NETWORK_NAME="$new_network"
          save_config
          success "网络名称已更新为: $NETWORK_NAME"
          info "配置已保存到: $CONFIG_FILE"
        else
          info "网络名称保持不变"
        fi
        pause
        ;;
      3)
        clear_screen
        cat <<EOF
${C_CYAN}当前 AstrBot 端口映射: ${C_BRIGHT_WHITE}$ASTRBOT_PORT${C_RESET}

${C_BRIGHT_YELLOW}端口映射格式说明:${C_RESET}
  ${C_GREEN}•${C_RESET} 单个端口: ${C_BRIGHT_WHITE}宿主机端口:容器端口${C_RESET}
    示例: ${C_CYAN}6185:6185${C_RESET}
  ${C_GREEN}•${C_RESET} 多个端口: 用逗号分隔
    示例: ${C_CYAN}6185:6185,8080:8080,9000:9000${C_RESET}

EOF
        read -r -p "${C_BRIGHT_BLUE}请输入新的端口映射 (留空保持不变):${C_RESET} " new_port || true
        if [[ -n "$new_port" ]]; then
          # 移除空格
          new_port="${new_port// /}"
          if validate_port_mapping "$new_port"; then
            ASTRBOT_PORT="$new_port"
            save_config
            success "AstrBot 端口映射已更新为: $ASTRBOT_PORT"
            info "配置已保存到: $CONFIG_FILE"
            warn "注意: 需要重新部署服务才能生效"
          else
            err "无效的端口映射格式"
            err "格式: 宿主机端口:容器端口 或 端口1:端口1,端口2:端口2"
            err "端口范围: 1-65535"
          fi
        else
          info "端口映射保持不变"
        fi
        pause
        ;;
      4)
        clear_screen
        cat <<EOF
${C_CYAN}当前 NapCat 端口映射: ${C_BRIGHT_WHITE}$NAPCAT_PORT${C_RESET}

${C_BRIGHT_YELLOW}端口映射格式说明:${C_RESET}
  ${C_GREEN}•${C_RESET} 单个端口: ${C_BRIGHT_WHITE}宿主机端口:容器端口${C_RESET}
    示例: ${C_CYAN}6099:6099${C_RESET}
  ${C_GREEN}•${C_RESET} 多个端口: 用逗号分隔
    示例: ${C_CYAN}6099:6099,3000:3000,8000:8000${C_RESET}

EOF
        read -r -p "${C_BRIGHT_BLUE}请输入新的端口映射 (留空保持不变):${C_RESET} " new_port || true
        if [[ -n "$new_port" ]]; then
          # 移除空格
          new_port="${new_port// /}"
          if validate_port_mapping "$new_port"; then
            NAPCAT_PORT="$new_port"
            save_config
            success "NapCat 端口映射已更新为: $NAPCAT_PORT"
            info "配置已保存到: $CONFIG_FILE"
            warn "注意: 需要重新部署服务才能生效"
          else
            err "无效的端口映射格式"
            err "格式: 宿主机端口:容器端口 或 端口1:端口1,端口2:端口2"
            err "端口范围: 1-65535"
          fi
        else
          info "端口映射保持不变"
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
service_dependencies(){ echo ""; }

service_action(){
  local action="$1" base="$2" svc="$3"; shift 3
  local deps="$(service_dependencies "$svc")"
  # 依赖处理（仅 start/restart 时启动依赖）
  if [[ "$action" =~ ^(start|restart)$ && -n "$deps" ]]; then
    for d in $deps; do docker start "$d" >/dev/null 2>&1 || docker restart "$d" >/dev/null 2>&1 || true; done
  fi
  case "$action" in
    start)   info "启动 $svc ..."; compose_exec "$base" up -d "$svc" 2>/dev/null || docker start "$svc" 2>/dev/null || err "启动失败" ;;
    stop)    info "停止 $svc ..."; compose_exec "$base" stop "$svc" 2>/dev/null || docker stop "$svc" 2>/dev/null || warn "容器不存在" ;;
    restart) info "重启 $svc ..."; compose_exec "$base" restart "$svc" 2>/dev/null || docker restart "$svc" 2>/dev/null || err "重启失败" ;;
    rebuild)
      info "正在检查 $svc 镜像更新..."
      # 获取当前镜像的 digest
      local current_digest=""
      current_digest=$(docker inspect "$svc" --format='{{.Image}}' 2>/dev/null || echo "")

      # 强制拉取最新镜像（Docker 会智能地只下载变化的层）
      info "正在拉取最新镜像..."
      if compose_exec "$base" pull "$svc"; then
        # 获取拉取后的镜像 digest
        local image_name=""
        image_name=$(docker inspect "$svc" --format='{{.Config.Image}}' 2>/dev/null || echo "")
        local new_digest=""
        if [[ -n "$image_name" ]]; then
          new_digest=$(docker images --no-trunc --quiet "$image_name" 2>/dev/null | head -1 || echo "")
        fi

        # 对比 digest 判断是否有更新
        if [[ -n "$current_digest" && -n "$new_digest" && "$current_digest" == "$new_digest" ]]; then
          info "镜像已是最新版本，无需重建"
        else
          info "检测到镜像更新，正在重建容器..."
          compose_exec "$base" up -d "$svc" || { err "重建容器失败"; return 1; }
          success "容器已使用最新镜像重建"
        fi
      else
        err "拉取镜像失败"
        return 1
      fi
      ;;
    delete)  docker rm -fv "$svc" 2>/dev/null || warn "容器不存在" ;;
  esac
  # 停止或删除依赖
  if [[ "$action" == "stop" && -n "$deps" ]]; then for d in $deps; do docker stop "$d" 2>/dev/null || true; done; fi
  success "$svc $action 完成"
}

# ==================== 服务操作 ====================
start_service(){ service_action start "$1" "$2"; pause; }
stop_service(){ service_action stop "$1" "$2"; pause; }
restart_service(){ service_action restart "$1" "$2"; pause; }
show_service_logs(){
  local base="$1" service_name="$2"
  info "正在获取 $service_name 服务的日志（按 Ctrl+C 退出）..."
  docker logs -f --tail 100 "$service_name" 2>/dev/null || err "无法获取日志 - 容器不存在"
}
rebuild_service(){ local base="$1" service_name="$2"; warn "这会拉取最新镜像并重建容器 $service_name"; read -r -p "确认? (Y/N): " c || true; [[ "$c" =~ ^[Yy]$ ]] || { info "已取消"; pause; return 0; }; service_action rebuild "$base" "$service_name"; pause; }

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

# AstrBot 密码管理
manage_astrbot_password(){
  local base="$1"
  local config_file="$base/astrbot/data/cmd_config.json"

  # 检查配置文件是否存在
  if [[ ! -f "$config_file" ]]; then
    err "配置文件不存在: $config_file"
    warn "请确保 AstrBot 已正确部署并至少运行过一次"
    pause
    return 1
  fi

  while true; do
    clear_screen

    # 读取当前账号信息
    local current_username=""
    if has_cmd jq && jq -e '.dashboard.username' "$config_file" >/dev/null 2>&1; then
      current_username=$(jq -r '.dashboard.username // "未设置"' "$config_file" 2>/dev/null || echo "读取失败")
    else
      # 如果没有 jq，使用 grep 和 sed
      current_username=$(grep -o '"username"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | sed 's/.*"username"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "读取失败")
      [[ -z "$current_username" ]] && current_username="未设置"
    fi

    cat <<EOF
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}           AstrBot 密码管理${C_RESET}
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}当前账号信息:${C_RESET}
  ${C_CYAN}用户名:${C_RESET} ${C_BRIGHT_WHITE}$current_username${C_RESET}
  ${C_CYAN}密码:${C_RESET}   ${C_DIM}(已加密，无法直接查看)${C_RESET}

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}操作选项:${C_RESET}
  ${C_GREEN}1)${C_RESET} 修改用户名
  ${C_GREEN}2)${C_RESET} 修改密码
  ${C_BRIGHT_RED}0)${C_RESET} 返回上级菜单

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-2):${C_RESET} " opt || true

    case "$opt" in
      1)
        read -r -p "${C_BRIGHT_BLUE}请输入新的用户名:${C_RESET} " new_username || true
        if [[ -z "$new_username" ]]; then
          warn "用户名不能为空"
          pause
          continue
        fi

        # 更新用户名
        if has_cmd jq; then
          jq ".dashboard.username = \"$new_username\"" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        else
          sed -i.bak "s/\"username\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"username\": \"$new_username\"/" "$config_file"
        fi

        success "用户名已更新为: $new_username"
        info "请重启 AstrBot 服务使更改生效"
        pause
        ;;

      2)
        read -r -s -p "${C_BRIGHT_BLUE}请输入新密码:${C_RESET} " new_password || true
        echo ""
        if [[ -z "$new_password" ]]; then
          warn "密码不能为空"
          pause
          continue
        fi

        read -r -s -p "${C_BRIGHT_BLUE}请再次输入新密码:${C_RESET} " confirm_password || true
        echo ""

        if [[ "$new_password" != "$confirm_password" ]]; then
          err "两次输入的密码不一致"
          pause
          continue
        fi

        # 生成 MD5 哈希
        local password_hash
        password_hash=$(generate_md5 "$new_password")
        if [[ $? -ne 0 ]]; then
          pause
          continue
        fi

        # 更新密码
        if has_cmd jq; then
          jq ".dashboard.password = \"$password_hash\"" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        else
          sed -i.bak "s/\"password\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"password\": \"$password_hash\"/" "$config_file"
        fi

        success "密码已更新"
        info "请重启 AstrBot 服务使更改生效"
        pause
        ;;

      0) return 0 ;;
      *) warn "无效选择" && sleep 1 ;;
    esac
  done
}

# NapCat 密码管理
manage_napcat_password(){
  local base="$1"
  local config_file="$base/napcat/config/webui.json"

  # 检查配置文件是否存在
  if [[ ! -f "$config_file" ]]; then
    err "配置文件不存在: $config_file"
    warn "请确保 NapCat 已正确部署并至少运行过一次"
    pause
    return 1
  fi

  while true; do
    clear_screen

    # 读取当前密码
    local current_token=""
    if has_cmd jq && jq -e '.token' "$config_file" >/dev/null 2>&1; then
      current_token=$(jq -r '.token // "未设置"' "$config_file" 2>/dev/null || echo "读取失败")
    else
      # 如果没有 jq，使用 grep 和 sed
      current_token=$(grep -o '"token"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | sed 's/.*"token"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/' || echo "读取失败")
      [[ -z "$current_token" ]] && current_token="未设置"
    fi

    cat <<EOF
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}           NapCat 密码管理${C_RESET}
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}当前密码信息:${C_RESET}
  ${C_CYAN}密码 (Token):${C_RESET} ${C_BRIGHT_WHITE}$current_token${C_RESET}

${C_DIM}注意: NapCat 使用明文存储密码${C_RESET}

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}操作选项:${C_RESET}
  ${C_GREEN}1)${C_RESET} 修改密码
  ${C_BRIGHT_RED}0)${C_RESET} 返回上级菜单

${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-1):${C_RESET} " opt || true

    case "$opt" in
      1)
        read -r -p "${C_BRIGHT_BLUE}请输入新密码:${C_RESET} " new_token || true
        if [[ -z "$new_token" ]]; then
          warn "密码不能为空"
          pause
          continue
        fi

        # 更新密码
        if has_cmd jq; then
          jq ".token = \"$new_token\"" "$config_file" > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"
        else
          sed -i.bak "s/\"token\"[[:space:]]*:[[:space:]]*\"[^\"]*\"/\"token\": \"$new_token\"/" "$config_file"
        fi

        success "密码已更新为: $new_token"
        info "请重启 NapCat 服务使更改生效"
        pause
        ;;

      0) return 0 ;;
      *) warn "无效选择" && sleep 1 ;;
    esac
  done
}

# 密码管理主函数
manage_password(){
  local base="$1"
  local service_name="$2"

  case "$service_name" in
    astrbot)
      manage_astrbot_password "$base"
      ;;
    napcat)
      manage_napcat_password "$base"
      ;;
    *)
      err "不支持的服务: $service_name"
      pause
      ;;
  esac
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
  read -r -p "${C_BRIGHT_BLUE}选择 (1-3):${C_RESET} " ch || true
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
  local all_services=("astrbot" "napcat")

  for svc in "${all_services[@]}"; do
    local container_name="$svc"

    # 检查容器是否存在和运行状态
    local container_exists
    container_exists=$(docker ps -a --filter "name=$container_name" --format '{{.Names}}' 2>/dev/null | head -1)

    if [[ -z "$container_exists" ]]; then
       echo "${C_BRIGHT_WHITE}服务名称: ${C_CYAN}$svc${C_RESET}"
       echo "${C_BRIGHT_WHITE}当前状态: ${C_YELLOW}⚠️  未安装${C_RESET}"
       echo "${C_BRIGHT_GREEN}${sep}${C_RESET}"
       continue
    fi

    local status="$(docker ps --filter "name=$container_name" --format '{{.Status}}' 2>/dev/null || echo '')"
    local status_icon="${C_RED}❌ 未运行${C_RESET}"
    if [[ "$status" == *"Up"* ]]; then
      status_icon="${C_GREEN}✅ 运行中${C_RESET}"
    fi

    # 获取容器IP、镜像名和端口信息
    local container_ip="$(docker inspect "$container_name" --format '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' 2>/dev/null || echo '-')"
    local image="$(docker ps -a --filter "name=$container_name" --format '{{.Image}}' 2>/dev/null || echo '-')"
    # 优化端口显示，过滤 IPv6，替换换行符为逗号
    local ports="$(docker ps -a --filter "name=$container_name" --format '{{.Ports}}' 2>/dev/null | tr ',' '\n' | grep -v "\[::\]" | sed 's/0\.0\.0\.0://g' | sed 's/^[ \t]*//' | tr '\n' ',' | sed 's/,$//' || echo '-')"
    [[ -z "$ports" || "$ports" == " " ]] && ports="-"

    echo "${C_BRIGHT_WHITE}服务名称: ${C_CYAN}$svc${C_RESET}"
    echo "${C_BRIGHT_WHITE}当前状态: $status_icon"
    echo "${C_BRIGHT_WHITE}容器 IP : ${C_MAGENTA}$container_ip${C_RESET}"
    echo "${C_BRIGHT_WHITE}镜像名称: ${C_BLUE}$image${C_RESET}"
    echo "${C_BRIGHT_WHITE}端口映射: ${C_YELLOW}$ports${C_RESET}"
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
        # 优化端口显示，过滤 IPv6
        ports="$(docker ps --filter "name=$service_name" --format '{{.Ports}}' 2>/dev/null | tr ',' '\n' | grep -v "\[::\]" | sed 's/0\.0\.0\.0://g' | sed 's/^[ \t]*//' | tr '\n' ',' | sed 's/,$//' || echo '-')"
        [[ -z "$ports" || "$ports" == " " ]] && ports="-"
      else
        status_icon="❌ 未运行"
        # 获取镜像信息（即使未运行也能显示）
        image="$(docker ps -a --filter "name=$service_name" --format '{{.Image}}' 2>/dev/null || echo '-')"
      fi
    fi
    
    cat <<EOF
${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
  ${C_BRIGHT_BLUE}${C_BOLD}⚙️  $service_name 管理菜单${C_RESET}
${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

  ${C_CYAN}服务状态:${C_RESET} ${C_BRIGHT_WHITE}$status_icon${C_RESET}
  ${C_CYAN}容器名称:${C_RESET} ${C_BRIGHT_WHITE}$service_name${C_RESET}
  ${C_CYAN}镜像名称:${C_RESET} ${C_BRIGHT_WHITE}$image${C_RESET}
  ${C_CYAN}容器IP:${C_RESET} ${C_BRIGHT_WHITE}$container_ip${C_RESET}
  ${C_CYAN}端口映射:${C_RESET} ${C_BRIGHT_WHITE}$ports${C_RESET}

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
${C_BRIGHT_BLUE}${C_BOLD}      AstrBot 集成部署与管理脚本 v2.1.0${C_RESET}
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
