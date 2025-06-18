rm -rf ./WeChatPadPro/redis/data/*
docker network create --driver bridge astrbot
docker compose -f./astrbot.yml up -d
docker compose -f./WeChatPadPro/wechat.yml up -d