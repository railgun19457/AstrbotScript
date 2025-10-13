/**
 * WeChatPadPro-861 Swagger UI 增强动画效果
 * 为标签添加动态效果和交互功能
 */

(function() {
  // 标签增强功能
  function enhanceTags() {
    // 获取所有标签
    const tags = document.querySelectorAll('.swagger-ui .opblock-tag');
    
    // 为每个标签添加增强效果
    tags.forEach(tag => {
      // 提取标签名称
      const tagName = tag.getAttribute('data-tag') || '';
      const tagText = tag.querySelector('span').textContent;
      
      // 添加中文描述
      let description = '';
      
      // 根据标签名添加对应的中文描述
      switch(tagName.toLowerCase()) {
        case 'admin':
          description = '管理模块';
          break;
        case 'login':
          description = '登录模块';
          break;
        case 'message':
          description = '消息模块';
          break;
        case 'ws':
          description = '同步消息';
          break;
        case 'user':
          description = '用户模块';
          break;
        case 'group':
          description = '群组模块';
          break;
        case 'pay':
          description = '支付模块';
          break;
        case 'friend':
          description = '朋友模块';
          break;
        case 'label':
          description = '标签模块';
          break;
        case 'applet':
          description = '公众号/小程序';
          break;
        case 'sns':
          description = '朋友圈模块';
          break;
        case 'finder':
          description = '视频号模块';
          break;
        case 'favor':
          description = '收藏模块';
          break;
        case 'friendcircle':
          description = '朋友圈模块';
          break;
        default:
          description = '';
      }
      
      // 如果有描述，添加到标签中
      if (description) {
        const descElement = document.createElement('small');
        descElement.className = 'tag-description';
        descElement.textContent = description;
        tag.querySelector('span').appendChild(descElement);
      }
      
      // 添加点击波纹效果
      tag.addEventListener('click', function(e) {
        // 创建波纹元素
        const ripple = document.createElement('span');
        ripple.className = 'tag-ripple';
        
        // 设置波纹样式
        ripple.style.cssText = `
          position: absolute;
          background-color: rgba(255, 255, 255, 0.7);
          border-radius: 50%;
          transform: scale(0);
          animation: ripple 0.6s linear;
          pointer-events: none;
        `;
        
        // 计算波纹位置
        const rect = this.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height);
        const x = e.clientX - rect.left - size / 2;
        const y = e.clientY - rect.top - size / 2;
        
        ripple.style.width = ripple.style.height = `${size}px`;
        ripple.style.left = `${x}px`;
        ripple.style.top = `${y}px`;
        
        // 添加波纹元素
        this.appendChild(ripple);
        
        // 动画结束后移除波纹
        setTimeout(() => {
          ripple.remove();
        }, 600);
      });
      
      // 添加悬停效果
      tag.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-2px)';
      });
      
      tag.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0)';
      });
    });
    
    // 添加波纹动画样式
    const style = document.createElement('style');
    style.textContent = `
      @keyframes ripple {
        to {
          transform: scale(4);
          opacity: 0;
        }
      }
    `;
    document.head.appendChild(style);
  }
  
  // 增强API操作块
  function enhanceOperations() {
    // 获取所有操作块
    const operations = document.querySelectorAll('.swagger-ui .opblock');
    
    operations.forEach(operation => {
      // 添加悬停效果
      operation.addEventListener('mouseenter', function() {
        this.style.transform = 'translateY(-2px)';
      });
      
      operation.addEventListener('mouseleave', function() {
        this.style.transform = 'translateY(0)';
      });
    });
  }
  
  // 增强头部
  function enhanceHeader() {
    const topbar = document.querySelector('.swagger-ui .topbar');
    if (!topbar) return;
    
    // 创建动态背景元素
    const dynamicBg = document.createElement('div');
    dynamicBg.className = 'topbar-dynamic-bg';
    dynamicBg.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: linear-gradient(135deg, rgba(52, 152, 219, 0.3), rgba(155, 89, 182, 0.3));
      z-index: -1;
      overflow: hidden;
    `;
    
    // 创建动态图形
    for (let i = 0; i < 5; i++) {
      const shape = document.createElement('div');
      const size = Math.random() * 60 + 20;
      const x = Math.random() * 100;
      const y = Math.random() * 100;
      const duration = Math.random() * 20 + 10;
      const delay = Math.random() * 5;
      
      shape.style.cssText = `
        position: absolute;
        width: ${size}px;
        height: ${size}px;
        border-radius: 50%;
        background-color: rgba(255, 255, 255, 0.1);
        top: ${y}%;
        left: ${x}%;
        animation: float ${duration}s ease-in-out ${delay}s infinite alternate;
      `;
      
      dynamicBg.appendChild(shape);
    }
    
    // 添加动画样式
    const style = document.createElement('style');
    style.textContent = `
      @keyframes float {
        0% {
          transform: translate(0, 0) scale(1);
          opacity: 0.1;
        }
        100% {
          transform: translate(20px, -20px) scale(1.2);
          opacity: 0.2;
        }
      }
    `;
    document.head.appendChild(style);
    
    // 添加动态背景到头部
    topbar.appendChild(dynamicBg);
    
    // 添加品牌标识
    const brandLogo = document.createElement('div');
    brandLogo.className = 'brand-logo';
    brandLogo.style.cssText = `
      position: absolute;
      left: 20px;
      top: 50%;
      transform: translateY(-50%);
      font-size: 20px;
      font-weight: bold;
      color: #fff;
      display: flex;
      align-items: center;
      z-index: 1;
    `;
    
    // 添加图标
    const icon = document.createElement('span');
    icon.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
      </svg>
    `;
    icon.style.marginRight = '10px';
    
    brandLogo.appendChild(icon);
    brandLogo.appendChild(document.createTextNode('WeChatPadPro-861'));
    
    topbar.appendChild(brandLogo);
  }
  
  // 增强信息区域
  function enhanceInfo() {
    const info = document.querySelector('.swagger-ui .info');
    if (!info) return;
    
    // 添加装饰元素
    const decoration = document.createElement('div');
    decoration.className = 'info-decoration';
    decoration.style.cssText = `
      position: absolute;
      top: -50px;
      right: -50px;
      width: 150px;
      height: 150px;
      background-color: rgba(52, 152, 219, 0.1);
      border-radius: 50%;
      z-index: 0;
    `;
    
    info.appendChild(decoration);
    
    // 为标题添加渐变效果
    const title = info.querySelector('.title');
    if (title) {
      title.style.background = 'linear-gradient(to right, #3498db, #9b59b6)';
      title.style.webkitBackgroundClip = 'text';
      title.style.webkitTextFillColor = 'transparent';
      title.style.display = 'inline-block';
    }
  }
  
  // 在页面加载完成后初始化增强功能
  window.addEventListener('load', function() {
    // 等待Swagger UI加载完成
    const checkSwaggerLoaded = setInterval(function() {
      if (window.ui) {
        clearInterval(checkSwaggerLoaded);
        
        // 添加CSS样式
        const style = document.createElement('style');
        style.textContent = `
          /* 标签波纹效果 */
          .tag-ripple {
            position: absolute;
            background-color: rgba(255, 255, 255, 0.7);
            border-radius: 50%;
            transform: scale(0);
            animation: ripple 0.6s linear;
            pointer-events: none;
          }
          
          @keyframes ripple {
            to {
              transform: scale(4);
              opacity: 0;
            }
          }
          
          /* 标签图标 */
          .tag-icon {
            margin-right: 10px;
            opacity: 0.8;
          }
          
          /* 标签描述 */
          .tag-description {
            margin-left: 10px;
            font-size: 14px;
            color: #7f8c8d;
            font-weight: normal;
          }
        `;
        document.head.appendChild(style);
        
        // 在DOM完全加载后执行增强功能
        setTimeout(() => {
          enhanceTags();
          enhanceOperations();
          enhanceHeader();
          enhanceInfo();
          
          // 监听DOM变化，处理动态加载的元素
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.addedNodes.length) {
                setTimeout(() => {
                  enhanceTags();
                  enhanceOperations();
                }, 100);
              }
            });
          });
          
          observer.observe(document.getElementById('swagger-ui'), {
            childList: true,
            subtree: true
          });
        }, 1000);
      }
    }, 100);
  });
})(); 