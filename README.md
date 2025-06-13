#### 使用说明
**仅适用于Linux环境下使用Docker部署**

**文件夹内有3个sh脚本，对应3种组合**
- astrbot_napcat.sh:一键部署astrbot和napcat
- astrbot_wechatpadpro.sh:一键部署astrbot和WeChatPadPro
- astrbot_napcat_wechatpadpro:一键部署astrbot、napcat和WeChatPadPro

#### 使用方法
在本文件夹下运行
**sudo ./<对应脚本>**

#### 注意事项
- 使用的端口(面板)
  - 6185：AstrBot面板
  - 6099：NapCat面板
  - 8059：WeChatPadPro面板
- 使用的端口(其他)
  - 33306:3306：mysql_wx
  - 36379:6379：redis_wx
  - 6199：反向ws

- 消息平台配置填写可参考文件夹内图片
- WeChatPadPro如果使用代理登录，可在8059面板直接填写代理地址
- AstrBot面板默认账号和密码为astrbot
- NapCat面板默认密码为NapCat

#### 官方文档
** https://astrbot.app/what-is-astrbot.html **