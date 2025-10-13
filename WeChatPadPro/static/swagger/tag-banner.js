/**
 * WeChatPadPro-861 Swagger UI 头部标签专题背景动态效果
 */

(function() {
  // 初始化头部标签专题背景
  function initTagBanner() {
    // 检查元素是否存在
    const banner = document.querySelector('.custom-header-banner');
    if (!banner) return;
    
    // 添加更多动态形状
    addDynamicShapes(banner);
    
    // 添加粒子效果
    createParticles(banner);
    
    // 添加鼠标跟随效果
    addMouseFollowEffect(banner);
    
    // 添加标签图标动画
    animateTagIcons();
    
    // 添加文字渐变效果
    addTextGradientEffect();
    
    // 监听窗口大小变化，保持响应式
    window.addEventListener('resize', () => {
      // 清除旧的粒子
      const particlesContainer = banner.querySelector('.particles');
      if (particlesContainer) {
        particlesContainer.innerHTML = '';
        // 重新创建粒子
        createParticles(banner);
      }
    });
  }
  
  // 添加更多动态形状
  function addDynamicShapes(banner) {
    const background = banner.querySelector('.banner-background');
    if (!background) return;
    
    // 添加更多不同形状的元素
    const shapes = [
      { type: 'circle', count: 3 },
      { type: 'square', count: 2 },
      { type: 'triangle', count: 2 },
      { type: 'hexagon', count: 1 }
    ];
    
    shapes.forEach(shapeConfig => {
      for (let i = 0; i < shapeConfig.count; i++) {
        const shape = document.createElement('div');
        const size = Math.random() * 30 + 15;
        const x = Math.random() * 100;
        const y = Math.random() * 100;
        const delay = Math.random() * 5;
        const duration = Math.random() * 15 + 15;
        const opacity = Math.random() * 0.1 + 0.05;
        
        shape.className = 'banner-shape custom-shape';
        
        let shapeStyle = `
          position: absolute;
          width: ${size}px;
          height: ${size}px;
          top: ${y}%;
          left: ${x}%;
          opacity: ${opacity};
          animation: float ${duration}s infinite alternate ease-in-out;
          animation-delay: ${delay}s;
        `;
        
        if (shapeConfig.type === 'circle') {
          shapeStyle += `
            border-radius: 50%;
            background: radial-gradient(circle at 30% 40%, rgba(255, 255, 255, 0.7), rgba(255, 255, 255, 0.1));
          `;
        } else if (shapeConfig.type === 'square') {
          shapeStyle += `
            background: radial-gradient(circle at 30% 40%, rgba(255, 255, 255, 0.6), rgba(255, 255, 255, 0.1));
            transform: rotate(${Math.random() * 45}deg);
          `;
        } else if (shapeConfig.type === 'triangle') {
          shape.innerHTML = `
            <svg width="${size}" height="${size}" viewBox="0 0 100 100">
              <polygon points="50,15 90,85 10,85" fill="rgba(255, 255, 255, 0.15)" />
            </svg>
          `;
          shapeStyle += `
            transform-origin: center;
          `;
        } else if (shapeConfig.type === 'hexagon') {
          shape.innerHTML = `
            <svg width="${size}" height="${size}" viewBox="0 0 100 100">
              <polygon points="50,0 93.3,25 93.3,75 50,100 6.7,75 6.7,25" fill="rgba(255, 255, 255, 0.15)" />
            </svg>
          `;
          shapeStyle += `
            transform-origin: center;
          `;
        }
        
        shape.style.cssText = shapeStyle;
        background.appendChild(shape);
      }
    });
  }
  
  // 创建粒子效果
  function createParticles(banner) {
    const particlesContainer = banner.querySelector('.particles');
    if (!particlesContainer) return;
    
    // 清空容器
    particlesContainer.innerHTML = '';
    
    // 计算粒子数量 (基于容器宽度)
    const bannerWidth = banner.offsetWidth;
    const particleCount = Math.max(20, Math.floor(bannerWidth / 50));
    
    // 创建粒子
    for (let i = 0; i < particleCount; i++) {
      const particle = document.createElement('div');
      particle.className = 'particle';
      
      // 随机大小和位置
      const size = Math.random() * 6 + 2;
      const x = Math.random() * 100;
      const y = Math.random() * 100;
      
      // 随机透明度
      const opacity = Math.random() * 0.5 + 0.1;
      
      // 随机动画延迟和持续时间
      const delay = Math.random() * 5;
      const duration = Math.random() * 20 + 10;
      
      // 设置样式
      particle.style.cssText = `
        width: ${size}px;
        height: ${size}px;
        left: ${x}%;
        top: ${y}%;
        opacity: ${opacity};
        filter: blur(${Math.random() * 1 + 0.5}px);
        animation: particleFloat ${duration}s infinite ease-in-out;
        animation-delay: ${delay}s;
      `;
      
      particlesContainer.appendChild(particle);
    }
    
    // 添加粒子动画样式
    if (!document.getElementById('particle-styles')) {
      const style = document.createElement('style');
      style.id = 'particle-styles';
      style.textContent = `
        @keyframes particleFloat {
          0%, 100% {
            transform: translate(0, 0);
          }
          25% {
            transform: translate(${Math.random() * 30 + 10}px, ${Math.random() * 30 + 10}px);
          }
          50% {
            transform: translate(${Math.random() * -30 - 10}px, ${Math.random() * 30 + 10}px);
          }
          75% {
            transform: translate(${Math.random() * -30 - 10}px, ${Math.random() * -30 - 10}px);
          }
        }
      `;
      document.head.appendChild(style);
    }
  }
  
  // 添加鼠标跟随效果
  function addMouseFollowEffect(banner) {
    banner.addEventListener('mousemove', (e) => {
      const rect = banner.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      
      // 计算鼠标位置相对于元素中心的偏移
      const centerX = rect.width / 2;
      const centerY = rect.height / 2;
      const moveX = (x - centerX) / 30;
      const moveY = (y - centerY) / 30;
      
      // 应用位移效果到背景形状
      const shapes = banner.querySelectorAll('.banner-shape');
      shapes.forEach((shape, index) => {
        const factor = (index % 4 + 1) * 0.4;
        shape.style.transform = `translate(${moveX * factor}px, ${moveY * factor}px) rotate(${moveX * factor}deg)`;
      });
      
      // 应用位移效果到粒子
      const particles = banner.querySelectorAll('.particle');
      particles.forEach((particle, index) => {
        const factor = (index % 5 + 1) * 0.2;
        particle.style.transform = `translate(${moveX * factor * 2}px, ${moveY * factor * 2}px)`;
      });
      
      // 应用光照效果
      const light = banner.querySelector('.banner-light') || createLightEffect(banner);
      light.style.background = `radial-gradient(circle at ${x}px ${y}px, rgba(255,255,255,0.2) 0%, rgba(255,255,255,0) 60%)`;
    });
    
    banner.addEventListener('mouseleave', () => {
      // 重置所有形状位置
      const shapes = banner.querySelectorAll('.banner-shape');
      shapes.forEach(shape => {
        shape.style.transform = '';
      });
      
      // 重置所有粒子位置
      const particles = banner.querySelectorAll('.particle');
      particles.forEach(particle => {
        particle.style.transform = '';
      });
    });
  }
  
  // 创建光照效果元素
  function createLightEffect(banner) {
    const light = document.createElement('div');
    light.className = 'banner-light';
    light.style.cssText = `
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      pointer-events: none;
      z-index: 2;
    `;
    banner.appendChild(light);
    return light;
  }
  
  // 添加标签图标动画
  function animateTagIcons() {
    const icons = document.querySelectorAll('.tag-icon');
    
    icons.forEach((icon, index) => {
      // 设置初始延迟动画
      icon.style.animation = `fadeInUp 0.5s ease forwards ${index * 0.1}s`;
      
      // 添加悬浮动画
      icon.addEventListener('mouseenter', () => {
        const svg = icon.querySelector('svg');
        if (svg) {
          svg.style.transform = 'scale(1.2)';
          svg.style.transition = 'transform 0.3s ease';
        }
      });
      
      icon.addEventListener('mouseleave', () => {
        const svg = icon.querySelector('svg');
        if (svg) {
          svg.style.transform = '';
        }
      });
      
      // 添加点击波纹效果
      icon.addEventListener('click', (e) => {
        const ripple = document.createElement('span');
        ripple.className = 'icon-ripple';
        
        const rect = icon.getBoundingClientRect();
        const size = Math.max(rect.width, rect.height) * 2.5;
        
        ripple.style.cssText = `
          position: absolute;
          top: 50%;
          left: 50%;
          width: ${size}px;
          height: ${size}px;
          transform: translate(-50%, -50%) scale(0);
          background-color: rgba(255, 255, 255, 0.4);
          border-radius: 50%;
          animation: iconRipple 0.6s ease-out forwards;
          pointer-events: none;
        `;
        
        // 添加动画样式
        if (!document.getElementById('icon-animation-styles')) {
          const style = document.createElement('style');
          style.id = 'icon-animation-styles';
          style.textContent = `
            @keyframes iconRipple {
              to {
                transform: translate(-50%, -50%) scale(1);
                opacity: 0;
              }
            }
            
            @keyframes fadeInUp {
              from {
                opacity: 0;
                transform: translateY(20px);
              }
              to {
                opacity: 1;
                transform: translateY(0);
              }
            }
          `;
          document.head.appendChild(style);
        }
        
        icon.appendChild(ripple);
        
        // 移除波纹元素
        setTimeout(() => {
          ripple.remove();
        }, 600);
        
        // 滚动到对应的标签
        scrollToTag(icon);
      });
    });
  }
  
  // 添加文字渐变效果
  function addTextGradientEffect() {
    const title = document.querySelector('.banner-title');
    if (!title) return;
    
    // 添加渐变动画
    title.style.cssText = `
      background: linear-gradient(to right, #ffffff, #a3bded, #ffffff);
      background-size: 200% auto;
      background-clip: text;
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      animation: textShine 3s linear infinite;
    `;
    
    // 添加动画样式
    if (!document.getElementById('text-shine-style')) {
      const style = document.createElement('style');
      style.id = 'text-shine-style';
      style.textContent = `
        @keyframes textShine {
          to {
            background-position: 200% center;
          }
        }
      `;
      document.head.appendChild(style);
    }
    
    // 为副标题添加渐变入场动画
    const subtitle = document.querySelector('.banner-subtitle');
    if (subtitle) {
      subtitle.style.opacity = '0';
      subtitle.style.transform = 'translateY(10px)';
      subtitle.style.transition = 'opacity 0.8s ease, transform 0.8s ease';
      
      // 延迟显示
      setTimeout(() => {
        subtitle.style.opacity = '0.95';
        subtitle.style.transform = 'translateY(0)';
      }, 300);
    }
  }
  
  // 滚动到对应的标签
  function scrollToTag(iconElement) {
    // 获取标签ID
    const tagId = iconElement.getAttribute('data-tag');
    if (!tagId) return;
    
    // 查找对应的标签元素
    const tagElement = document.querySelector(`.swagger-ui .opblock-tag[data-tag="${tagId}"]`);
    if (tagElement) {
      // 展开标签
      if (tagElement.getAttribute('aria-expanded') === 'false') {
        tagElement.click();
      }
      
      // 滚动到标签位置
      setTimeout(() => {
        tagElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 100);
    }
  }
  
  // 在页面加载完成后初始化
  window.addEventListener('load', function() {
    // 等待Swagger UI加载完成
    const checkSwaggerLoaded = setInterval(function() {
      if (window.ui) {
        clearInterval(checkSwaggerLoaded);
        
        // 在DOM完全加载后执行增强功能
        setTimeout(() => {
          initTagBanner();
        }, 1000);
      }
    }, 100);
  });
})(); 