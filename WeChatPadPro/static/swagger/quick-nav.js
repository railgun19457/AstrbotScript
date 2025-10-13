/**
 * WeChatPadPro-861 Swagger UI 快捷导航
 * 提供一个浮动的快速导航菜单，帮助用户在大型 API 文档中轻松导航
 */

(function() {
  // 在 DOM 加载完成后执行
  document.addEventListener('DOMContentLoaded', function() {
    // 创建观察器以监听 Swagger UI 加载完成
    const observer = new MutationObserver(function(mutations, obs) {
      // 检查是否有 opblock-tag 元素，这表示 API 标签已加载
      const tags = document.querySelectorAll('.opblock-tag');
      if (tags.length > 0) {
        // 标签已加载，创建快捷导航
        createQuickNav(tags);
        // 停止观察
        obs.disconnect();
        
        // 添加新的观察器来监视新标签的添加
        observeNewTags();
      }
    });
    
    // 开始观察 DOM 变化
    observer.observe(document, {
      childList: true,
      subtree: true
    });
  });
  
  /**
   * 观察新标签的添加
   */
  function observeNewTags() {
    const tagObserver = new MutationObserver(function(mutations) {
      let needsUpdate = false;
      
      mutations.forEach(function(mutation) {
        if (mutation.addedNodes.length > 0) {
          mutation.addedNodes.forEach(function(node) {
            if (node.nodeType === 1 && (
                node.classList.contains('opblock-tag') || 
                node.querySelector('.opblock-tag')
            )) {
              needsUpdate = true;
            }
          });
        }
      });
      
      if (needsUpdate) {
        // 更新导航
        const tags = document.querySelectorAll('.opblock-tag');
        updateQuickNav(tags);
      }
    });
    
    // 监视 Swagger UI 容器
    const swaggerUI = document.querySelector('.swagger-ui');
    if (swaggerUI) {
      tagObserver.observe(swaggerUI, {
        childList: true,
        subtree: true
      });
    }
  }
  
  /**
   * 创建快捷导航
   * @param {NodeList} tags API 标签元素集合
   */
  function createQuickNav(tags) {
    // 检查是否已存在快捷导航
    if (document.getElementById('quick-nav')) {
      return;
    }
    
    // 创建样式
    const style = document.createElement('style');
    style.textContent = `
      #quick-nav {
        position: fixed;
        right: 20px;
        top: 50%;
        transform: translateY(-50%);
        background: white;
        border-radius: 8px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        z-index: 1000;
        transition: all 0.3s ease;
        max-height: 80vh;
        overflow-y: auto;
        scrollbar-width: thin;
        padding: 10px 0;
        opacity: 0.3;
      }
      
      #quick-nav:hover {
        opacity: 1;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
      }
      
      #quick-nav::-webkit-scrollbar {
        width: 4px;
      }
      
      #quick-nav::-webkit-scrollbar-track {
        background: transparent;
      }
      
      #quick-nav::-webkit-scrollbar-thumb {
        background: #ddd;
        border-radius: 2px;
      }
      
      #quick-nav .quick-nav-title {
        padding: 5px 15px;
        font-size: 12px;
        font-weight: 600;
        color: #6b7280;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        border-bottom: 1px solid #f3f4f6;
        margin-bottom: 5px;
      }
      
      #quick-nav ul {
        list-style: none;
        padding: 0;
        margin: 0;
      }
      
      #quick-nav li {
        padding: 0;
        margin: 0;
      }
      
      #quick-nav a {
        display: block;
        padding: 8px 15px;
        color: #4b5563;
        text-decoration: none;
        font-size: 13px;
        transition: all 0.2s ease;
        border-left: 3px solid transparent;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 180px;
      }
      
      #quick-nav a:hover {
        background-color: #f9fafb;
        color: #4e54c8;
      }
      
      #quick-nav a.active {
        background-color: #f3f4f6;
        color: #4e54c8;
        border-left-color: #4e54c8;
        font-weight: 500;
      }
      
      #quick-nav .toggle-nav {
        position: absolute;
        top: 10px;
        right: 10px;
        background: none;
        border: none;
        color: #9ca3af;
        cursor: pointer;
        padding: 2px;
        border-radius: 4px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      
      #quick-nav .toggle-nav:hover {
        color: #4e54c8;
        background-color: #f3f4f6;
      }
      
      #quick-nav.collapsed {
        width: 40px;
        overflow: hidden;
      }
      
      #quick-nav.collapsed .quick-nav-title,
      #quick-nav.collapsed ul {
        display: none;
      }
      
      #quick-nav.collapsed .toggle-nav {
        position: static;
        width: 100%;
        height: 30px;
      }
      
      @media (max-width: 768px) {
        #quick-nav {
          bottom: 20px;
          top: auto;
          right: 20px;
          transform: none;
          max-height: 50vh;
        }
      }
    `;
    
    // 创建导航容器
    const nav = document.createElement('div');
    nav.id = 'quick-nav';
    
    // 创建标题
    const title = document.createElement('div');
    title.className = 'quick-nav-title';
    title.textContent = '快速导航';
    
    // 创建切换按钮
    const toggleButton = document.createElement('button');
    toggleButton.className = 'toggle-nav';
    toggleButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>';
    toggleButton.title = '折叠/展开导航';
    toggleButton.onclick = function() {
      nav.classList.toggle('collapsed');
      if (nav.classList.contains('collapsed')) {
        toggleButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18l6-6-6-6"/></svg>';
      } else {
        toggleButton.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M15 18l-6-6 6-6"/></svg>';
      }
    };
    
    // 创建标签列表
    const ul = document.createElement('ul');
    
    // 添加到 DOM
    nav.appendChild(title);
    nav.appendChild(toggleButton);
    nav.appendChild(ul);
    document.body.appendChild(nav);
    document.head.appendChild(style);
    
    // 填充标签
    updateQuickNav(tags);
    
    // 添加滚动事件监听器，高亮当前可见的标签
    window.addEventListener('scroll', function() {
      highlightVisibleTag();
    });
  }
  
  /**
   * 更新快捷导航内容
   * @param {NodeList} tags API 标签元素集合
   */
  function updateQuickNav(tags) {
    const ul = document.querySelector('#quick-nav ul');
    if (!ul) return;
    
    // 清除现有项目
    ul.innerHTML = '';
    
    // 添加标签项目
    tags.forEach(function(tag) {
      const tagId = tag.getAttribute('id') || '';
      if (!tagId) return;
      
      // 获取标签文本
      let tagText = '';
      const heading = tag.querySelector('h3 > a.nostyle');
      if (heading) {
        tagText = heading.textContent.trim();
      }
      
      if (!tagText) return;
      
      // 创建列表项
      const li = document.createElement('li');
      const a = document.createElement('a');
      a.href = `#${tagId}`;
      a.setAttribute('data-tag-id', tagId);
      a.textContent = tagText;
      
      // 点击事件
      a.addEventListener('click', function(e) {
        e.preventDefault();
        
        // 平滑滚动到目标
        const targetElement = document.getElementById(tagId);
        if (targetElement) {
          // 考虑页面顶部固定元素的高度
          const offset = 80;
          const targetPosition = targetElement.getBoundingClientRect().top + window.pageYOffset - offset;
          
          window.scrollTo({
            top: targetPosition,
            behavior: 'smooth'
          });
          
          // 高亮被点击的项目
          document.querySelectorAll('#quick-nav a').forEach(function(link) {
            link.classList.remove('active');
          });
          a.classList.add('active');
        }
      });
      
      li.appendChild(a);
      ul.appendChild(li);
    });
    
    // 初始高亮
    highlightVisibleTag();
  }
  
  /**
   * 高亮当前可见的标签
   */
  function highlightVisibleTag() {
    // 获取所有标签
    const tags = document.querySelectorAll('.opblock-tag');
    if (tags.length === 0) return;
    
    // 找到当前可见的标签
    let currentVisibleTag = null;
    const offset = 100; // 考虑顶部固定元素的高度
    
    tags.forEach(function(tag) {
      const rect = tag.getBoundingClientRect();
      if (rect.top <= offset && rect.bottom > 0) {
        currentVisibleTag = tag;
      }
    });
    
    // 如果没有找到可见标签，使用第一个标签
    if (!currentVisibleTag && tags.length > 0) {
      currentVisibleTag = tags[0];
    }
    
    // 高亮对应的导航项
    if (currentVisibleTag) {
      const tagId = currentVisibleTag.getAttribute('id');
      if (tagId) {
        document.querySelectorAll('#quick-nav a').forEach(function(link) {
          if (link.getAttribute('data-tag-id') === tagId) {
            link.classList.add('active');
          } else {
            link.classList.remove('active');
          }
        });
      }
    }
  }
})(); 