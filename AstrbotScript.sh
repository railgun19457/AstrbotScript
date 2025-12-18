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
EOF
}

# ==================== 设置菜单 ====================
menu_settings(){
  while true; do
    clear_screen
    cat <<EOF
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}           环境配置设置${C_RESET}
${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}当前配置:${C_RESET}
  ${C_CYAN}📁 安装目录:${C_RESET}  ${C_BRIGHT_WHITE}$BASE_DIR${C_RESET}
  ${C_CYAN}🌐 网络名称:${C_RESET}  ${C_BRIGHT_WHITE}$NETWORK_NAME${C_RESET}

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

${C_BRIGHT_YELLOW}修改选项:${C_RESET}
  ${C_GREEN}1)${C_RESET} 修改安装目录
  ${C_GREEN}2)${C_RESET} 修改网络名称
  
  ${C_BRIGHT_RED}0)${C_RESET} 返回主菜单

${C_BRIGHT_MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-2):${C_RESET} " opt || true

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
      ${C_BRIGHT_RED}4)${C_RESET} 返回主菜单
${C_BRIGHT_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (1-4):${C_RESET} " opt || true

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
      4) return 0 ;;
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
    rebuild) info "升级 $svc ..."; compose_exec "$base" pull "$svc" && compose_exec "$base" up -d --build "$svc" || err "升级失败" ;;
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
rebuild_service(){ local base="$1" service_name="$2"; warn "这会拉取最新镜像并升级 $service_name"; read -r -p "确认? (Y/N): " c || true; [[ "$c" =~ ^[Yy]$ ]] || { info "已取消"; pause; return 0; }; service_action rebuild "$base" "$service_name"; pause; }

# ==================== Compose 文件操作 ====================
delete_service(){
  local base="$1" service_name="$2"; clear_screen; cat <<EOF
${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_RED}${C_BOLD}      ⚠ 删除 ${C_BRIGHT_WHITE}$service_name${C_RESET}${C_BRIGHT_RED} 服务确认${C_RESET}
${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}

  ${C_YELLOW}1)${C_RESET} 仅删除容器  ${C_DIM}(保留数据: ${C_BRIGHT_WHITE}$base/$service_name${C_RESET}${C_DIM})${C_RESET}
  ${C_YELLOW}2)${C_RESET} 删除容器与数据  ${C_RED}(不可恢复)${C_RESET}
  ${C_YELLOW}3)${C_RESET} 取消

${C_BRIGHT_RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF
  read -r -p "${C_BRIGHT_BLUE}选择 (1-3):${C_RESET} " ch || true
  case "$ch" in
    1) read -r -p "${C_BRIGHT_BLUE}确认? (Y/N):${C_RESET} " c || true; [[ "$c" =~ ^[Yy]$ ]] && service_action delete "$base" "$service_name" && info "保留数据: $base/$service_name" ;;
    2) read -r -p "${C_BRIGHT_RED}${C_BOLD}确认完全删除? (Y/N):${C_RESET} " c || true; [[ "$c" =~ ^[Yy]$ ]] || { info "已取消"; pause; return 0; }; service_action delete "$base" "$service_name"; rm -rf -- "$base/$service_name"; info "${C_RED}数据目录已删除${C_RESET}" ;;
    3) info "已取消" ;;
    *) warn "无效选择" ;;
  esac
  pause
}

# ==================== 服务状态显示 ====================
show_all_services_status(){
  clear_screen
  
  cat <<EOF
${C_BRIGHT_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
${C_BRIGHT_BLUE}${C_BOLD}                                        📊 服务状态${C_RESET}
${C_BRIGHT_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF
  
  # 表头（调整列宽以适应内容）
  printf "${C_BRIGHT_CYAN}%-12s %-14s %-18s %-22s %-36s${C_RESET}\n" "状态" "服务名" "容器IP" "镜像" "端口"
  echo "${C_BRIGHT_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
  
  # 定义所有可能的服务
  local all_services=("astrbot" "napcat")
  
  for svc in "${all_services[@]}"; do
    local container_name="$svc"
    
    # 检查容器是否存在和运行状态
    local container_exists
    container_exists=$(docker ps -a --filter "name=$container_name" --format '{{.Names}}' 2>/dev/null | head -1)
    
    if [[ -z "$container_exists" ]]; then
      printf "%-12s %-14s %-16s %-20s %-30s\n" "⚠️  未安装" "$svc" "-" "-" "-"
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
  
  echo "${C_BRIGHT_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
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

  ${C_GREEN}[1]${C_RESET} 启动服务               ${C_GREEN}[2]${C_RESET} 停止服务
  ${C_GREEN}[3]${C_RESET} 重启服务               ${C_GREEN}[4]${C_RESET} 查看日志
  ${C_GREEN}[5]${C_RESET} 升级服务 (更新镜像)    ${C_BRIGHT_RED}[6]${C_RESET} 删除服务
  ${C_BRIGHT_BLUE}[0]${C_RESET} 返回上级菜单

${C_GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}
EOF

    read -r -p "${C_BRIGHT_BLUE}请选择 (0-6):${C_RESET} " opt || true

    case "$opt" in
      1) start_service "$BASE_DIR" "$service_name" ;;
      2) stop_service "$BASE_DIR" "$service_name" ;;
      3) restart_service "$BASE_DIR" "$service_name" ;;
      4) show_service_logs "$BASE_DIR" "$service_name" ;;
      5) rebuild_service "$BASE_DIR" "$service_name" ;;
      6) delete_service "$BASE_DIR" "$service_name" ;;
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
${C_BRIGHT_BLUE}${C_BOLD}      AstrBot 集成部署与管理脚本 v2.0.1${C_RESET}
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
