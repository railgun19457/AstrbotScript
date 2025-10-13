/**
 * WeChatPadPro-861 Swagger UI 主题强制器
 * 彻底禁用主题选择并强制使用自定义主题
 */

(function() {
  // 在 DOM 加载完成后执行
  document.addEventListener('DOMContentLoaded', function() {
    // 立即执行一次清除
    disableThemeSelector();
    
    // 创建观察器以监听 Swagger UI 加载完成和 DOM 变化
    const observer = new MutationObserver(function(mutations) {
      // 检查是否有主题选择器相关元素被添加
      let hasThemeElements = false;
      
      mutations.forEach(function(mutation) {
        if (mutation.addedNodes.length > 0) {
          mutation.addedNodes.forEach(function(node) {
            if (node.nodeType === 1) { // 元素节点
              // 检查是否是主题选择器相关元素
              if (node.classList && 
                  (node.classList.contains('topbar') || 
                   node.querySelector('.topbar') || 
                   node.querySelector('.schemes-wrapper') ||
                   node.querySelector('[data-name="themes"]') ||
                   node.querySelector('[data-name="theme"]'))) {
                hasThemeElements = true;
              }
              
              // 检查是否包含选择框
              if (node.querySelectorAll && node.querySelectorAll('select').length > 0) {
                const selects = node.querySelectorAll('select');
                selects.forEach(function(select) {
                  // 检查选择框的选项是否包含主题相关文本
                  const options = select.querySelectorAll('option');
                  for (let i = 0; i < options.length; i++) {
                    const option = options[i];
                    if (option.textContent.toLowerCase().includes('theme') || 
                        option.value.toLowerCase().includes('theme')) {
                      hasThemeElements = true;
                      // 立即移除这个选择框
                      select.parentNode.style.display = 'none';
                      break;
                    }
                  }
                });
              }
            }
          });
        }
      });
      
      // 如果发现主题选择器相关元素，重新应用禁用逻辑
      if (hasThemeElements) {
        disableThemeSelector();
      }
    });
    
    // 开始观察整个文档的变化
    observer.observe(document.documentElement, {
      childList: true,
      subtree: true
    });
    
    // 设置定时器，定期检查并移除主题选择器
    setInterval(disableThemeSelector, 1000);
  });
  
  /**
   * 彻底禁用主题选择功能并强制使用自定义主题
   */
  function disableThemeSelector() {
    // 1. 使用 CSS 隐藏主题选择器相关元素
    ensureStyleExists();
    
    // 2. 使用 JavaScript 移除主题选择器相关元素
    removeThemeElements();
    
    // 3. 修改 Swagger UI 配置
    updateSwaggerConfig();
    
    // 4. 清除本地存储中的主题设置
    clearLocalStorage();
    
    // 5. 覆盖主题切换函数
    overrideThemeSwitchFunctions();
  }
  
  /**
   * 确保禁用主题选择器的样式存在
   */
  function ensureStyleExists() {
    // 检查是否已存在样式元素
    if (!document.getElementById('theme-enforcer-style')) {
      const style = document.createElement('style');
      style.id = 'theme-enforcer-style';
      style.textContent = `
        /* 隐藏所有主题选择器相关元素 */
        .swagger-ui .topbar,
        .swagger-ui .scheme-container,
        .swagger-ui .scheme-container .schemes-wrapper,
        .swagger-ui select[data-name="themes"],
        .swagger-ui select[data-name="theme"],
        .swagger-ui .select-label[data-name="themes"],
        .swagger-ui .select-label[data-name="theme"],
        .swagger-ui .download-url-wrapper,
        .swagger-ui .servers-title,
        .swagger-ui .servers > label,
        .swagger-ui .servers,
        .swagger-ui section.models,
        .swagger-ui .base-url {
          display: none !important;
          visibility: hidden !important;
          opacity: 0 !important;
          pointer-events: none !important;
          position: absolute !important;
          left: -9999px !important;
          top: -9999px !important;
          max-height: 0 !important;
          overflow: hidden !important;
          z-index: -1000 !important;
          clip: rect(0, 0, 0, 0) !important;
          clip-path: inset(50%) !important;
        }
        
        /* 强制应用我们的自定义主题样式 */
        body {
          background-color: #f9fafc !important;
        }
        
        /* 隐藏任何包含 theme 文本的选择框 */
        .swagger-ui select:has(option:contains("theme")),
        .swagger-ui select:has(option[value*="theme"]) {
          display: none !important;
        }
      `;
      document.head.appendChild(style);
    }
  }
  
  /**
   * 使用 JavaScript 移除主题选择器相关元素
   */
  function removeThemeElements() {
    // 查找并移除主题选择器相关元素
    const selectors = [
      '.topbar',
      '.scheme-container',
      '.schemes-wrapper',
      'select[data-name="themes"]',
      'select[data-name="theme"]',
      '.select-label[data-name="themes"]',
      '.select-label[data-name="theme"]',
      '.download-url-wrapper',
      '.servers-title',
      '.servers',
      'section.models'
    ];
    
    selectors.forEach(function(selector) {
      const elements = document.querySelectorAll(selector);
      elements.forEach(function(element) {
        if (element.parentNode) {
          element.style.display = 'none';
          element.style.visibility = 'hidden';
          element.style.opacity = '0';
          element.style.pointerEvents = 'none';
        }
      });
    });
    
    // 查找所有选择框，检查是否包含主题相关选项
    const selects = document.querySelectorAll('select');
    selects.forEach(function(select) {
      const options = select.querySelectorAll('option');
      let hasThemeOption = false;
      
      for (let i = 0; i < options.length; i++) {
        const option = options[i];
        if (option.textContent.toLowerCase().includes('theme') || 
            option.value.toLowerCase().includes('theme')) {
          hasThemeOption = true;
          break;
        }
      }
      
      if (hasThemeOption && select.parentNode) {
        select.parentNode.style.display = 'none';
      }
    });
  }
  
  /**
   * 修改 Swagger UI 配置
   */
  function updateSwaggerConfig() {
    if (window.ui && window.ui.getConfigs) {
      try {
        const configs = window.ui.getConfigs();
        
        // 禁用主题相关选项
        configs.withCredentials = false;
        configs.defaultModelRendering = "model";
        configs.defaultModelExpandDepth = -1;
        configs.displayRequestDuration = true;
        configs.syntaxHighlight = {
          activated: true,
          theme: "agate" // 固定使用 agate 主题
        };
        
        // 强制使用独立布局
        configs.layout = "StandaloneLayout";
        
        // 更新配置
        if (window.ui.configsActions && window.ui.configsActions.toggle) {
          window.ui.configsActions.toggle();
        }
      } catch (error) {
        console.error('更新 Swagger UI 配置时出错:', error);
      }
    }
  }
  
  /**
   * 清除本地存储中的主题设置
   */
  function clearLocalStorage() {
    try {
      // 清除所有与主题相关的本地存储项
      const keysToRemove = [
        'swagger-ui-theme',
        'swagger-ui-theme-mode',
        'swagger-theme',
        'swagger-editor-theme',
        'swagger-ui-defaultModelsExpandDepth',
        'swagger-ui-defaultModelExpandDepth'
      ];
      
      keysToRemove.forEach(function(key) {
        localStorage.removeItem(key);
        sessionStorage.removeItem(key);
      });
    } catch (error) {
      console.error('清除本地存储时出错:', error);
    }
  }
  
  /**
   * 覆盖主题切换函数
   */
  function overrideThemeSwitchFunctions() {
    try {
      // 如果存在 window.ui 和相关函数，尝试覆盖它们
      if (window.ui) {
        // 覆盖可能的主题切换函数
        const noopFunc = function() { return false; };
        
        // 尝试修改各种可能用于切换主题的函数
        if (window.ui.actions) {
          if (window.ui.actions.setTheme) window.ui.actions.setTheme = noopFunc;
          if (window.ui.actions.changeTheme) window.ui.actions.changeTheme = noopFunc;
          if (window.ui.actions.updateTheme) window.ui.actions.updateTheme = noopFunc;
        }
        
        // 尝试禁用可能的主题系统
        if (window.ui.system && window.ui.system.actions) {
          if (window.ui.system.actions.setTheme) window.ui.system.actions.setTheme = noopFunc;
          if (window.ui.system.actions.changeTheme) window.ui.system.actions.changeTheme = noopFunc;
          if (window.ui.system.actions.updateTheme) window.ui.system.actions.updateTheme = noopFunc;
        }
      }
      
      // 覆盖可能的全局主题切换函数
      if (window.setTheme) window.setTheme = function() { return false; };
      if (window.changeTheme) window.changeTheme = function() { return false; };
      if (window.updateTheme) window.updateTheme = function() { return false; };
    } catch (error) {
      console.error('覆盖主题切换函数时出错:', error);
    }
  }
})(); 