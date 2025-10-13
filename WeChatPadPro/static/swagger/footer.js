/**
 * WeChatPadPro-861 Swagger UI 自定义页脚组件
 * 为 Swagger UI 添加专业的页脚，包含版权信息、链接和附加功能
 */

(function() {
  // 在 DOM 加载完成后执行
  document.addEventListener('DOMContentLoaded', function() {
    // 创建观察器以监听 Swagger UI 加载完成
    const observer = new MutationObserver(function(mutations, obs) {
      const swaggerUI = document.querySelector('.swagger-ui');
      if (swaggerUI && swaggerUI.querySelector('.information-container')) {
        // Swagger UI 已加载，添加页脚
        addCustomFooter();
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
   * 添加自定义页脚到 Swagger UI
   */
  function addCustomFooter() {
    // 创建页脚容器
    const footerContainer = document.createElement('div');
    footerContainer.className = 'footer-container';
    
    // 创建页脚内容
    const footer = document.createElement('div');
    footer.className = 'custom-footer';
    
    // 获取当前年份
    const currentYear = new Date().getFullYear();
    
    // 设置页脚 HTML 内容
    footer.innerHTML = `
      <div class="footer-content">
        <div class="footer-section brand">
          <div class="footer-logo">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="32" height="32">
              <path fill="#4e54c8" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
            </svg>
          </div>
          <div class="footer-title">WeChatPadPro-861 API</div>
        </div>
        
        <div class="footer-section links">
          <div class="footer-links">
            <a href="#" class="footer-link">文档</a>
            <a href="#" class="footer-link">指南</a>
            <a href="#" class="footer-link">开发者中心</a>
            <a href="#" class="footer-link">支持</a>
          </div>
        </div>
        
        <div class="footer-section info">
          <div class="copyright">© ${currentYear} WeChatPadPro-861. 保留所有权利。</div>
        </div>
      </div>
      
      <div class="footer-bottom">
        <div class="footer-bottom-text">
          API 接口文档 | 版本 1.0.0
        </div>
        <div class="footer-buttons">
          <button class="footer-button scroll-top">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M18 15l-6-6-6 6"/>
            </svg>
            回到顶部
          </button>
        </div>
      </div>
    `;
    
    // 添加样式
    const style = document.createElement('style');
    style.textContent = `
      .footer-container {
        margin-top: 40px;
        width: 100%;
        background-color: white;
        border-top: 1px solid #e5e7eb;
        box-shadow: 0 -4px 6px -1px rgba(0, 0, 0, 0.05);
      }
      
      .custom-footer {
        max-width: 1200px;
        margin: 0 auto;
        padding: 30px 5%;
        color: #4b5563;
        font-size: 14px;
      }
      
      .footer-content {
        display: flex;
        flex-wrap: wrap;
        justify-content: space-between;
        margin-bottom: 20px;
      }
      
      .footer-section {
        margin: 0 20px 20px 0;
      }
      
      .footer-section.brand {
        display: flex;
        align-items: center;
      }
      
      .footer-logo {
        margin-right: 10px;
      }
      
      .footer-title {
        font-size: 18px;
        font-weight: 600;
        color: #374151;
      }
      
      .footer-links {
        display: flex;
        flex-wrap: wrap;
      }
      
      .footer-link {
        margin-right: 20px;
        color: #4e54c8;
        text-decoration: none;
        transition: color 0.2s ease;
      }
      
      .footer-link:hover {
        color: #3c42b0;
        text-decoration: underline;
      }
      
      .copyright {
        color: #6b7280;
      }
      
      .footer-bottom {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding-top: 15px;
        border-top: 1px solid #e5e7eb;
      }
      
      .footer-bottom-text {
        color: #9ca3af;
        font-size: 12px;
      }
      
      .footer-buttons {
        display: flex;
      }
      
      .footer-button {
        display: flex;
        align-items: center;
        background: linear-gradient(to right, #4e54c8, #8f94fb);
        color: white;
        border: none;
        border-radius: 4px;
        padding: 8px 16px;
        font-size: 13px;
        cursor: pointer;
        transition: all 0.3s ease;
        box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
      }
      
      .footer-button svg {
        margin-right: 6px;
      }
      
      .footer-button:hover {
        background: linear-gradient(to right, #3c42b0, #6a6fd5);
        transform: translateY(-2px);
        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
      }
      
      .footer-button:active {
        transform: translateY(0);
      }
      
      @media (max-width: 768px) {
        .footer-content {
          flex-direction: column;
        }
        
        .footer-section {
          margin-right: 0;
          margin-bottom: 15px;
        }
        
        .footer-bottom {
          flex-direction: column;
          align-items: flex-start;
        }
        
        .footer-bottom-text {
          margin-bottom: 10px;
        }
      }
    `;
    
    // 将页脚添加到 DOM
    footerContainer.appendChild(footer);
    document.head.appendChild(style);
    
    // 找到 Swagger UI 容器并附加页脚
    const swaggerContainer = document.getElementById('swagger-ui');
    if (swaggerContainer) {
      swaggerContainer.appendChild(footerContainer);
      
      // 添加回到顶部按钮功能
      const scrollTopButton = document.querySelector('.footer-button.scroll-top');
      if (scrollTopButton) {
        scrollTopButton.addEventListener('click', function() {
          window.scrollTo({
            top: 0,
            behavior: 'smooth'
          });
        });
      }
    }
  }
})(); 