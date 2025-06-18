rm -rf ./WeChatPadPro/redis/data/*
docker network create --driver bridge astrbot
docker compose -f./astrbot_napcat.yml up -d
docker compose -f./napcat/napcat.yml up -d
docker compose -f./WeChatPadPro/wechat.yml up -d