#!/bin/bash

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 检查目录是否存在，不存在则创建
check_dir() {
  if [ ! -d "$1" ]; then
    echo -e "${YELLOW}目录 $1 不存在，正在创建...${NC}"
    mkdir -p "$1"
  fi
}

# 检查目录权限
check_permission() {
  if [ ! -w "$1" ]; then
    echo -e "${YELLOW}目录 $1 没有写权限，正在赋予 777 权限...${NC}"
    chmod -R 777 "$1"
  fi
}

# 组件部署函数
deploy_astrbot() {
  echo -e "${GREEN}正在部署 AstrBot...${NC}"
  check_dir ./data
  docker network create --driver bridge astrbot || true
  docker compose -f ./astrbot.yml up -d
}

deploy_napcat() {
  echo -e "${GREEN}正在部署 NapCat...${NC}"
  check_dir ./napcat/ntqq
  check_dir ./data
  docker network create --driver bridge astrbot || true
  docker compose -f ./astrbot_napcat.yml up -d
  docker compose -f ./napcat/napcat.yml up -d
}

deploy_wechatpadpro() {
  echo -e "${GREEN}正在部署 WeChatPadPro...${NC}"
  check_dir ./WeChatPadPro
  check_dir ./WeChatPadPro/mysql/data
  check_dir ./WeChatPadPro/redis/data
  check_dir ./WeChatPadPro/redis/conf
  check_permission ./WeChatPadPro/redis/conf
  docker network create --driver bridge astrbot || true
  docker compose -f ./WeChatPadPro/wechat.yml up -d
}

# 交互式选择
show_menu() {
  echo "请选择要部署的组件（可多选，空格分隔）："
  echo "1) AstrBot"
  echo "2) NapCat"
  echo "3) WeChatPadPro"
  echo "4) 全部部署"
  read -p "请输入编号（如 1 3 或 4）：" choices
}

show_menu

if [[ $choices =~ 4 ]]; then
  deploy_astrbot
  deploy_napcat
  deploy_wechatpadpro
else
  for c in $choices; do
    case $c in
      1) deploy_astrbot ;;
      2) deploy_napcat ;;
      3) deploy_wechatpadpro ;;
      *) echo -e "${RED}无效选项: $c${NC}" ;;
    esac
  done
fi

echo -e "${GREEN}部署完成！${NC}"
