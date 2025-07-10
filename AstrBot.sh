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
  echo -e "${YELLOW}正在赋予 $1 目录 777 权限...${NC}"
  chmod -R 777 "$1"
}

# 交互式选择
show_menu() {
  echo "请选择要部署的组合："
  echo "0) 仅部署 AstrBot(不推荐)"
  echo "1) AstrBot + NapCat"
  echo "2) AstrBot + WeChatPadPro"
  echo "3) AstrBot + NapCat + WeChatPadPro"
  read -p "请输入编号:" choice
}

show_menu

case $choice in
  0)
    docker network create --driver bridge astrbot || true
    echo -e "${GREEN}正在部署 AstrBot...${NC}"
    check_dir ./data
    docker compose -f ./astrbot.yml up -d
    ;;
  1)
    docker network create --driver bridge astrbot || true
    echo -e "${GREEN}正在部署 AstrBot...${NC}"
    check_dir ./data
    docker compose -f ./astrbot_napcat.yml up -d
    echo -e "${GREEN}正在部署 NapCat...${NC}"
    check_dir ./napcat/ntqq
    docker compose -f ./napcat/napcat.yml up -d
    ;;
  2)
    docker network create --driver bridge astrbot || true
    echo -e "${GREEN}正在部署 AstrBot...${NC}"
    check_dir ./data
    docker compose -f ./astrbot.yml up -d
    echo -e "${GREEN}正在部署 WeChatPadPro...${NC}"
    check_dir ./WeChatPadPro
    check_dir ./WeChatPadPro/mysql/data
    check_dir ./WeChatPadPro/redis/data
    check_dir ./WeChatPadPro/redis/conf
    check_permission ./WeChatPadPro/redis/conf
    docker compose -f ./WeChatPadPro/wechat.yml up -d
    ;;
  3)
    docker network create --driver bridge astrbot || true
    echo -e "${GREEN}正在部署 AstrBot...${NC}"
    check_dir ./data
    docker compose -f ./astrbot_napcat.yml up -d
    echo -e "${GREEN}正在部署 NapCat...${NC}"
    check_dir ./napcat/ntqq
    docker compose -f ./napcat/napcat.yml up -d
    echo -e "${GREEN}正在部署 WeChatPadPro...${NC}"
    check_dir ./WeChatPadPro
    check_dir ./WeChatPadPro/mysql/data
    check_dir ./WeChatPadPro/redis/data
    check_dir ./WeChatPadPro/redis/conf
    check_permission ./WeChatPadPro/redis/conf
    docker compose -f ./WeChatPadPro/wechat.yml up -d
    ;;
  *)
    echo -e "${RED}无效选项: $choice${NC}"
    exit 1
    ;;
esac

echo -e "${GREEN}部署完成！${NC}"
