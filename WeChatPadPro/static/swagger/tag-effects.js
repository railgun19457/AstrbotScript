/**
 * WeChatPadPro-861 Swagger UI 标签动态效果
 * 为标签添加动态背景和交互效果
 */

(function() {
  // 标签容器增强
  function enhanceTagContainers() {
    // 获取所有标签
    const tags = document.querySelectorAll('.swagger-ui .opblock-tag');
    
    tags.forEach(tag => {
      // 获取标签名称
      const tagName = tag.getAttribute('data-tag') || '';
      
      // 创建标签容器
      const tagSection = tag.closest('.opblock-tag-section');
      if (!tagSection) return;
      
      // 如果已经处理过，则跳过
      if (tagSection.classList.contains('enhanced')) return;
      
      // 创建标签容器
      const container = document.createElement('div');
      container.className = 'opblock-tag-container';
      container.setAttribute('data-tag', tagName);
      
      // 将标签移动到容器中
      const parent = tag.parentNode;
      parent.insertBefore(container, tag);
      container.appendChild(tag);
      
      // 标记为已处理
      tagSection.classList.add('enhanced');
      
      // 添加动态背景效果
      addDynamicBackground(container, tagName);
    });
  }
  
  // 添加动态背景效果
  function addDynamicBackground(container, tagName) {
    // 创建动态背景元素
    const bg = document.createElement('div');
    bg.className = 'tag-dynamic-bg';
    bg.style.cssText = `
      position: absolute;
      top: 0;
      right: 0;
      width: 100%;
      height: 100%;
      z-index: 0;
      overflow: hidden;
      border-radius: 10px;
      pointer-events: none;
    `;
    
    // 根据标签名称设置不同的背景颜色
    let primaryColor = '#3498db';
    let secondaryColor = '#2980b9';
    
    switch(tagName.toLowerCase()) {
      case 'admin':
      case '管理':
        primaryColor = '#e74c3c';
        secondaryColor = '#c0392b';
        break;
      case 'login':
      case '登录':
        primaryColor = '#3498db';
        secondaryColor = '#2980b9';
        break;
      case 'message':
      case '消息':
        primaryColor = '#2ecc71';
        secondaryColor = '#27ae60';
        break;
      case 'user':
      case '用户':
        primaryColor = '#9b59b6';
        secondaryColor = '#8e44ad';
        break;
      case 'group':
      case '群组':
        primaryColor = '#f39c12';
        secondaryColor = '#d35400';
        break;
      case 'friend':
      case '朋友':
        primaryColor = '#16a085';
        secondaryColor = '#1abc9c';
        break;
      case 'pay':
      case '支付':
        primaryColor = '#d35400';
        secondaryColor = '#e67e22';
        break;
      case 'favor':
      case '收藏':
        primaryColor = '#8e44ad';
        secondaryColor = '#9b59b6';
        break;
      case 'finder':
      case '视频号':
        primaryColor = '#2980b9';
        secondaryColor = '#3498db';
        break;
      case 'friendcircle':
      case '朋友圈':
        primaryColor = '#27ae60';
        secondaryColor = '#2ecc71';
        break;
    }
    
    // 创建动态图形
    for (let i = 0; i < 3; i++) {
      const shape = document.createElement('div');
      const size = Math.random() * 40 + 20;
      const x = Math.random() * 100;
      const y = Math.random() * 100;
      const opacity = Math.random() * 0.05 + 0.02;
      
      shape.style.cssText = `
        position: absolute;
        width: ${size}px;
        height: ${size}px;
        border-radius: 50%;
        background: ${i % 2 === 0 ? primaryColor : secondaryColor};
        top: ${y}%;
        right: ${x}%;
        opacity: ${opacity};
        filter: blur(${Math.random() * 5 + 5}px);
      `;
      
      bg.appendChild(shape);
    }
    
    // 添加背景到容器
    container.appendChild(bg);
    
    // 添加悬停效果
    container.addEventListener('mouseenter', () => {
      bg.querySelectorAll('div').forEach(shape => {
        shape.style.transform = 'scale(1.2)';
        shape.style.opacity = parseFloat(shape.style.opacity) * 1.5;
        shape.style.transition = 'all 0.5s ease';
      });
    });
    
    container.addEventListener('mouseleave', () => {
      bg.querySelectorAll('div').forEach(shape => {
        shape.style.transform = 'scale(1)';
        shape.style.opacity = parseFloat(shape.style.opacity) / 1.5;
        shape.style.transition = 'all 0.5s ease';
      });
    });
  }
  
  // 添加标签中文描述
  function addTagDescriptions() {
    const tags = document.querySelectorAll('.swagger-ui .opblock-tag');
    
    const descriptions = {
      'admin': '管理模块',
      'login': '登录模块',
      'message': '消息模块',
      'ws': '同步消息',
      'user': '用户模块',
      'group': '群组模块',
      'pay': '支付模块',
      'friend': '朋友模块',
      'label': '标签模块',
      'applet': '公众号/小程序',
      'sns': '朋友圈模块',
      'finder': '视频号模块',
      'favor': '收藏模块',
      'friendcircle': '朋友圈模块',
      'equipment': '设备模块',
      'other': '其他模块'
    };
    
    tags.forEach(tag => {
      const tagName = tag.getAttribute('data-tag') || '';
      const tagSpan = tag.querySelector('span');
      
      // 如果已经添加了描述，则跳过
      if (tag.querySelector('.tag-description')) return;
      
      // 添加中文描述
      if (descriptions[tagName.toLowerCase()]) {
        const desc = document.createElement('small');
        desc.className = 'tag-description';
        desc.textContent = descriptions[tagName.toLowerCase()];
        tagSpan.appendChild(desc);
      }
    });
  }
  
  // 添加标签点击动画
  function addTagClickAnimation() {
    const tags = document.querySelectorAll('.swagger-ui .opblock-tag');
    
    tags.forEach(tag => {
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
          z-index: 2;
        `;
        
        // 添加波纹动画样式
        if (!document.getElementById('ripple-style')) {
          const style = document.createElement('style');
          style.id = 'ripple-style';
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
    });
  }
  
  // 在页面加载完成后初始化
  window.addEventListener('load', function() {
    // 等待Swagger UI加载完成
    const checkSwaggerLoaded = setInterval(function() {
      if (window.ui) {
        clearInterval(checkSwaggerLoaded);
        
        // 在DOM完全加载后执行增强功能
        setTimeout(() => {
          enhanceTagContainers();
          addTagDescriptions();
          addTagClickAnimation();
          
          // 监听DOM变化，处理动态加载的元素
          const observer = new MutationObserver(function(mutations) {
            mutations.forEach(function(mutation) {
              if (mutation.addedNodes.length) {
                setTimeout(() => {
                  enhanceTagContainers();
                  addTagDescriptions();
                  addTagClickAnimation();
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