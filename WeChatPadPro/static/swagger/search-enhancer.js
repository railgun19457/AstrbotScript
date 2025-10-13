/**
 * WeChatPadPro-861 Swagger UI 搜索增强
 * 增强原生搜索功能，提供更直观的搜索体验和结果展示
 */

(function() {
  // 在 DOM 加载完成后执行
  document.addEventListener('DOMContentLoaded', function() {
    // 创建观察器以监听 Swagger UI 加载完成
    const observer = new MutationObserver(function(mutations, obs) {
      const swaggerUI = document.querySelector('.swagger-ui');
      const topbar = document.querySelector('.topbar');
      
      if (swaggerUI && (topbar || document.querySelector('.information-container'))) {
        // Swagger UI 已加载，增强搜索功能
        enhanceSearch();
        // 停止观察
        obs.disconnect();
      }
    });
    
    // 开始观察 DOM 变化
    observer.observe(document, {
      childList: true,
      subtree: true
    });
  });
  
  /**
   * 增强搜索功能
   */
  function enhanceSearch() {
    // 创建样式
    const style = document.createElement('style');
    style.textContent = `
      .enhanced-search-container {
        position: relative;
        margin: 20px auto;
        max-width: 600px;
        width: 100%;
        padding: 0 20px;
        z-index: 100;
      }
      
      .enhanced-search-box {
        position: relative;
        width: 100%;
      }
      
      .enhanced-search-input {
        width: 100%;
        padding: 12px 45px 12px 20px;
        border-radius: 30px;
        border: 1px solid #ddd;
        background-color: white;
        font-size: 15px;
        color: #333;
        transition: all 0.3s ease;
        box-shadow: 0 2px 10px rgba(0, 0, 0, 0.05);
      }
      
      .enhanced-search-input:focus {
        outline: none;
        border-color: #4e54c8;
        box-shadow: 0 0 0 3px rgba(78, 84, 200, 0.1), 0 2px 10px rgba(0, 0, 0, 0.1);
      }
      
      .enhanced-search-icon {
        position: absolute;
        right: 15px;
        top: 50%;
        transform: translateY(-50%);
        color: #9ca3af;
        cursor: pointer;
        transition: color 0.2s ease;
      }
      
      .enhanced-search-icon:hover {
        color: #4e54c8;
      }
      
      .enhanced-search-results {
        position: absolute;
        top: 100%;
        left: 0;
        right: 0;
        background-color: white;
        border-radius: 8px;
        margin-top: 10px;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
        max-height: 400px;
        overflow-y: auto;
        display: none;
        z-index: 1000;
      }
      
      .enhanced-search-results.active {
        display: block;
        animation: fadeIn 0.2s ease;
      }
      
      @keyframes fadeIn {
        from { opacity: 0; transform: translateY(-10px); }
        to { opacity: 1; transform: translateY(0); }
      }
      
      .enhanced-search-result-item {
        padding: 12px 15px;
        border-bottom: 1px solid #f3f4f6;
        cursor: pointer;
        transition: all 0.2s ease;
      }
      
      .enhanced-search-result-item:last-child {
        border-bottom: none;
      }
      
      .enhanced-search-result-item:hover {
        background-color: #f9fafb;
      }
      
      .enhanced-search-result-item.active {
        background-color: #f3f4f6;
      }
      
      .enhanced-search-result-tag {
        font-size: 12px;
        font-weight: 600;
        color: #4e54c8;
        margin-bottom: 5px;
        display: block;
      }
      
      .enhanced-search-result-title {
        font-size: 14px;
        color: #1f2937;
        margin-bottom: 5px;
        display: block;
      }
      
      .enhanced-search-result-path {
        font-size: 12px;
        color: #6b7280;
        font-family: monospace;
      }
      
      .enhanced-search-highlight {
        background-color: rgba(78, 84, 200, 0.1);
        color: #4e54c8;
        padding: 1px 4px;
        border-radius: 3px;
        font-weight: 500;
      }
      
      .enhanced-search-no-results {
        padding: 15px;
        color: #6b7280;
        text-align: center;
        font-size: 14px;
      }
      
      .enhanced-search-shortcuts {
        position: absolute;
        right: 45px;
        top: 50%;
        transform: translateY(-50%);
        display: flex;
        align-items: center;
      }
      
      .enhanced-search-shortcut {
        margin-right: 8px;
        font-size: 11px;
        padding: 3px 6px;
        border-radius: 4px;
        background-color: #f3f4f6;
        color: #6b7280;
        font-weight: 500;
      }
      
      .enhanced-search-result-method {
        display: inline-block;
        padding: 2px 8px;
        border-radius: 3px;
        font-size: 11px;
        font-weight: 600;
        margin-right: 8px;
        color: white;
      }
      
      .enhanced-search-result-method.get {
        background-color: #61affe;
      }
      
      .enhanced-search-result-method.post {
        background-color: #49cc90;
      }
      
      .enhanced-search-result-method.put {
        background-color: #fca130;
      }
      
      .enhanced-search-result-method.delete {
        background-color: #f93e3e;
      }
      
      .enhanced-search-result-method.patch {
        background-color: #50e3c2;
      }
      
      @media (max-width: 768px) {
        .enhanced-search-container {
          padding: 0 15px;
        }
        
        .enhanced-search-shortcuts {
          display: none;
        }
      }
    `;
    
    // 添加样式到头部
    document.head.appendChild(style);
    
    // 创建搜索容器
    const searchContainer = document.createElement('div');
    searchContainer.className = 'enhanced-search-container';
    
    // 创建搜索框
    const searchBox = document.createElement('div');
    searchBox.className = 'enhanced-search-box';
    
    // 创建搜索输入框
    const searchInput = document.createElement('input');
    searchInput.type = 'text';
    searchInput.className = 'enhanced-search-input';
    searchInput.placeholder = '搜索 API 接口、标签或描述...';
    searchInput.autocomplete = 'off';
    
    // 创建搜索图标
    const searchIcon = document.createElement('div');
    searchIcon.className = 'enhanced-search-icon';
    searchIcon.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="11" cy="11" r="8"/><path d="M21 21l-4.35-4.35"/></svg>';
    
    // 创建快捷键提示
    const shortcuts = document.createElement('div');
    shortcuts.className = 'enhanced-search-shortcuts';
    shortcuts.innerHTML = '<span class="enhanced-search-shortcut">Ctrl + K</span>';
    
    // 创建搜索结果容器
    const searchResults = document.createElement('div');
    searchResults.className = 'enhanced-search-results';
    
    // 组装搜索框
    searchBox.appendChild(searchInput);
    searchBox.appendChild(shortcuts);
    searchBox.appendChild(searchIcon);
    searchBox.appendChild(searchResults);
    searchContainer.appendChild(searchBox);
    
    // 找到合适的位置插入搜索框
    const informationContainer = document.querySelector('.information-container');
    if (informationContainer) {
      informationContainer.after(searchContainer);
    } else {
      const swaggerUI = document.querySelector('.swagger-ui');
      if (swaggerUI) {
        swaggerUI.prepend(searchContainer);
      }
    }
    
    // 搜索功能
    let currentResults = [];
    let selectedResultIndex = -1;
    
    // 键盘快捷键
    document.addEventListener('keydown', function(e) {
      // Ctrl + K 聚焦搜索框
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        searchInput.focus();
      }
      
      // 搜索结果导航
      if (searchResults.classList.contains('active')) {
        // 按下 Esc 键关闭搜索结果
        if (e.key === 'Escape') {
          closeSearchResults();
        }
        
        // 按下向下箭头选择下一个结果
        if (e.key === 'ArrowDown') {
          e.preventDefault();
          navigateResults(1);
        }
        
        // 按下向上箭头选择上一个结果
        if (e.key === 'ArrowUp') {
          e.preventDefault();
          navigateResults(-1);
        }
        
        // 按下回车键跳转到选中的结果
        if (e.key === 'Enter' && selectedResultIndex >= 0 && currentResults.length > 0) {
          e.preventDefault();
          const selectedItem = document.querySelector('.enhanced-search-result-item.active');
          if (selectedItem) {
            selectedItem.click();
          }
        }
      }
    });
    
    // 搜索图标点击事件
    searchIcon.addEventListener('click', function() {
      searchInput.focus();
      performSearch();
    });
    
    // 搜索输入事件
    searchInput.addEventListener('input', performSearch);
    
    // 搜索框焦点事件
    searchInput.addEventListener('focus', function() {
      if (searchInput.value.trim()) {
        performSearch();
      }
    });
    
    // 点击外部关闭搜索结果
    document.addEventListener('click', function(e) {
      if (!searchContainer.contains(e.target)) {
        closeSearchResults();
      }
    });
    
    /**
     * 执行搜索
     */
    function performSearch() {
      const query = searchInput.value.trim().toLowerCase();
      if (!query) {
        closeSearchResults();
        return;
      }
      
      // 搜索结果
      currentResults = [];
      
      // 搜索所有操作
      const operations = document.querySelectorAll('.opblock');
      operations.forEach(function(op) {
        // 查找方法、路径和描述
        const method = op.querySelector('.opblock-summary-method')?.textContent.trim().toLowerCase() || '';
        const path = op.querySelector('.opblock-summary-path')?.textContent.trim().toLowerCase() || '';
        const description = op.querySelector('.opblock-summary-description')?.textContent.trim().toLowerCase() || '';
        
        // 查找标签信息
        const tagSection = op.closest('.opblock-tag-section');
        const tagName = tagSection ? tagSection.querySelector('.opblock-tag')?.textContent.trim().toLowerCase() || '' : '';
        
        // 检查是否匹配
        if (method.includes(query) || path.includes(query) || description.includes(query) || tagName.includes(query)) {
          const methodType = op.classList.contains('opblock-get') ? 'get' : 
                           op.classList.contains('opblock-post') ? 'post' : 
                           op.classList.contains('opblock-put') ? 'put' : 
                           op.classList.contains('opblock-delete') ? 'delete' : 
                           op.classList.contains('opblock-patch') ? 'patch' : '';
          
          currentResults.push({
            element: op,
            method: method,
            methodType: methodType,
            path: path,
            description: description,
            tag: tagName
          });
        }
      });
      
      // 显示结果
      displaySearchResults(query);
    }
    
    /**
     * 显示搜索结果
     * @param {string} query 搜索查询
     */
    function displaySearchResults(query) {
      // 清空结果容器
      searchResults.innerHTML = '';
      
      // 重置选中索引
      selectedResultIndex = -1;
      
      if (currentResults.length === 0) {
        searchResults.innerHTML = '<div class="enhanced-search-no-results">未找到匹配的结果</div>';
        searchResults.classList.add('active');
        return;
      }
      
      // 排序结果（标签匹配优先，然后是路径匹配）
      currentResults.sort(function(a, b) {
        const aTagMatch = a.tag.includes(query) ? 1 : 0;
        const bTagMatch = b.tag.includes(query) ? 1 : 0;
        
        if (aTagMatch !== bTagMatch) {
          return bTagMatch - aTagMatch;
        }
        
        const aPathMatch = a.path.includes(query) ? 1 : 0;
        const bPathMatch = b.path.includes(query) ? 1 : 0;
        
        return bPathMatch - aPathMatch;
      });
      
      // 生成结果项
      currentResults.forEach(function(result, index) {
        const resultItem = document.createElement('div');
        resultItem.className = 'enhanced-search-result-item';
        resultItem.dataset.index = index;
        
        // 高亮匹配文本
        const highlightedTag = highlightText(result.tag, query);
        const highlightedPath = highlightText(result.path, query);
        const highlightedDescription = highlightText(result.description, query);
        
        resultItem.innerHTML = `
          <span class="enhanced-search-result-tag">${highlightedTag}</span>
          <div>
            <span class="enhanced-search-result-method ${result.methodType}">${result.method}</span>
            <span class="enhanced-search-result-title">${highlightedDescription || '无描述'}</span>
          </div>
          <span class="enhanced-search-result-path">${highlightedPath}</span>
        `;
        
        // 点击事件
        resultItem.addEventListener('click', function() {
          // 关闭搜索结果
          closeSearchResults();
          
          // 滚动到目标操作
          const targetElement = result.element;
          if (targetElement) {
            // 展开包含该操作的标签
            const tagElement = targetElement.closest('.opblock-tag-section');
            if (tagElement) {
              const isExpanded = !tagElement.querySelector('.no-margin');
              if (!isExpanded) {
                const tagButton = tagElement.querySelector('.opblock-tag');
                if (tagButton) {
                  tagButton.click();
                }
              }
              
              // 稍作延迟，确保标签展开
              setTimeout(function() {
                // 计算滚动位置
                const offset = 100; // 考虑页面顶部固定元素的高度
                const targetPosition = targetElement.getBoundingClientRect().top + window.pageYOffset - offset;
                
                // 平滑滚动
                window.scrollTo({
                  top: targetPosition,
                  behavior: 'smooth'
                });
                
                // 高亮效果
                targetElement.classList.add('search-highlighted');
                
                // 移除高亮效果
                setTimeout(function() {
                  targetElement.classList.remove('search-highlighted');
                }, 2000);
              }, 300);
            }
          }
        });
        
        searchResults.appendChild(resultItem);
      });
      
      // 显示结果容器
      searchResults.classList.add('active');
      
      // 添加高亮样式
      const highlightStyle = document.getElementById('search-highlight-style');
      if (!highlightStyle) {
        const style = document.createElement('style');
        style.id = 'search-highlight-style';
        style.textContent = `
          .search-highlighted {
            box-shadow: 0 0 0 3px rgba(78, 84, 200, 0.5) !important;
            animation: highlight-pulse 2s ease-out;
          }
          
          @keyframes highlight-pulse {
            0% { box-shadow: 0 0 0 0 rgba(78, 84, 200, 0.7); }
            70% { box-shadow: 0 0 0 10px rgba(78, 84, 200, 0); }
            100% { box-shadow: 0 0 0 0 rgba(78, 84, 200, 0); }
          }
        `;
        document.head.appendChild(style);
      }
    }
    
    /**
     * 高亮文本中的匹配部分
     * @param {string} text 原始文本
     * @param {string} query 搜索查询
     * @returns {string} 高亮后的 HTML
     */
    function highlightText(text, query) {
      if (!text) return '';
      
      const index = text.toLowerCase().indexOf(query.toLowerCase());
      if (index === -1) return text;
      
      const before = text.substring(0, index);
      const match = text.substring(index, index + query.length);
      const after = text.substring(index + query.length);
      
      return `${before}<span class="enhanced-search-highlight">${match}</span>${after}`;
    }
    
    /**
     * 关闭搜索结果
     */
    function closeSearchResults() {
      searchResults.classList.remove('active');
      selectedResultIndex = -1;
    }
    
    /**
     * 在搜索结果中导航
     * @param {number} direction 导航方向 (1: 下一个, -1: 上一个)
     */
    function navigateResults(direction) {
      if (currentResults.length === 0) return;
      
      // 计算新的索引
      selectedResultIndex += direction;
      
      // 循环索引
      if (selectedResultIndex < 0) {
        selectedResultIndex = currentResults.length - 1;
      } else if (selectedResultIndex >= currentResults.length) {
        selectedResultIndex = 0;
      }
      
      // 移除所有现有的活动状态
      document.querySelectorAll('.enhanced-search-result-item').forEach(function(item) {
        item.classList.remove('active');
      });
      
      // 设置新的活动项
      const activeItem = document.querySelector(`.enhanced-search-result-item[data-index="${selectedResultIndex}"]`);
      if (activeItem) {
        activeItem.classList.add('active');
        
        // 滚动到可见区域
        activeItem.scrollIntoView({
          behavior: 'smooth',
          block: 'nearest'
        });
      }
    }
  }
})(); 