/**
 * Swagger UI 主题生成器
 * 可以动态切换不同的主题样式
 */

(function() {
  // 主题配置
  const themes = {
    'default': {
      primaryColor: '#3498db',
      secondaryColor: '#2c3e50',
      backgroundColor: '#f8f9fa',
      textColor: '#212529',
      headingColor: '#2c3e50',
      linkColor: '#3498db',
      navBgColor: '#ffffff',
      methodColors: {
        get: '#61affe',
        post: '#49cc90',
        put: '#fca130',
        delete: '#f93e3e',
        patch: '#50e3c2',
        options: '#0d5aa7',
        head: '#9012fe'
      }
    },
    'dark': {
      primaryColor: '#61affe',
      secondaryColor: '#1a1a1a',
      backgroundColor: '#121212',
      textColor: '#e0e0e0',
      headingColor: '#ffffff',
      linkColor: '#61affe',
      navBgColor: '#1e1e1e',
      methodColors: {
        get: '#4990e2',
        post: '#2eca74',
        put: '#ff9f43',
        delete: '#ff5252',
        patch: '#3ad0b3',
        options: '#0d5aa7',
        head: '#9b59b6'
      }
    },
    'material': {
      primaryColor: '#6200ee',
      secondaryColor: '#03dac6',
      backgroundColor: '#ffffff',
      textColor: '#333333',
      headingColor: '#6200ee',
      linkColor: '#6200ee',
      navBgColor: '#f5f5f5',
      methodColors: {
        get: '#2196f3',
        post: '#4caf50',
        put: '#ff9800',
        delete: '#f44336',
        patch: '#00bcd4',
        options: '#673ab7',
        head: '#9c27b0'
      }
    },
    'corporate': {
      primaryColor: '#0078d4',
      secondaryColor: '#106ebe',
      backgroundColor: '#f8f8f8',
      textColor: '#323130',
      headingColor: '#0078d4',
      linkColor: '#0078d4',
      navBgColor: '#ffffff',
      methodColors: {
        get: '#0078d4',
        post: '#107c10',
        put: '#ffaa44',
        delete: '#d83b01',
        patch: '#008575',
        options: '#5c2d91',
        head: '#8764b8'
      }
    }
  };

  // 创建主题选择器
  function createThemeSelector() {
    const container = document.createElement('div');
    container.className = 'theme-selector';
    container.style.cssText = `
      position: fixed;
      top: 10px;
      right: 10px;
      z-index: 1000;
      background-color: #fff;
      border-radius: 4px;
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.1);
      padding: 10px;
      display: flex;
      align-items: center;
    `;

    const label = document.createElement('label');
    label.textContent = '选择主题: ';
    label.style.marginRight = '10px';
    label.style.fontWeight = '500';
    container.appendChild(label);

    const select = document.createElement('select');
    select.style.cssText = `
      padding: 5px 10px;
      border-radius: 4px;
      border: 1px solid #ddd;
      background-color: #fff;
      cursor: pointer;
    `;

    // 添加主题选项
    Object.keys(themes).forEach(theme => {
      const option = document.createElement('option');
      option.value = theme;
      option.textContent = theme.charAt(0).toUpperCase() + theme.slice(1);
      select.appendChild(option);
    });

    // 监听主题变化
    select.addEventListener('change', function() {
      applyTheme(this.value);
      localStorage.setItem('swagger_theme', this.value);
    });

    container.appendChild(select);
    document.body.appendChild(container);

    // 应用保存的主题
    const savedTheme = localStorage.getItem('swagger_theme');
    if (savedTheme && themes[savedTheme]) {
      select.value = savedTheme;
      applyTheme(savedTheme);
    }
  }

  // 应用主题
  function applyTheme(themeName) {
    const theme = themes[themeName] || themes.default;
    
    // 创建或更新主题样式
    let style = document.getElementById('swagger-dynamic-theme');
    if (!style) {
      style = document.createElement('style');
      style.id = 'swagger-dynamic-theme';
      document.head.appendChild(style);
    }

    style.textContent = `
      body {
        background-color: ${theme.backgroundColor};
        color: ${theme.textColor};
      }

      .swagger-ui .topbar {
        background-color: ${theme.secondaryColor};
      }

      .swagger-ui .info .title {
        color: ${theme.headingColor};
      }

      .swagger-ui a {
        color: ${theme.linkColor};
      }

      .swagger-ui .btn.execute {
        background-color: ${theme.primaryColor};
        border-color: ${theme.primaryColor};
      }

      .swagger-ui .opblock-tag {
        border-left: 4px solid ${theme.primaryColor};
      }

      .swagger-ui .opblock-tag:hover {
        background-color: ${theme.navBgColor};
      }

      .swagger-ui .opblock-get {
        border-color: ${theme.methodColors.get};
        background: rgba(${hexToRgb(theme.methodColors.get)}, 0.1);
      }

      .swagger-ui .opblock-post {
        border-color: ${theme.methodColors.post};
        background: rgba(${hexToRgb(theme.methodColors.post)}, 0.1);
      }

      .swagger-ui .opblock-put {
        border-color: ${theme.methodColors.put};
        background: rgba(${hexToRgb(theme.methodColors.put)}, 0.1);
      }

      .swagger-ui .opblock-delete {
        border-color: ${theme.methodColors.delete};
        background: rgba(${hexToRgb(theme.methodColors.delete)}, 0.1);
      }

      .swagger-ui .opblock-patch {
        border-color: ${theme.methodColors.patch};
        background: rgba(${hexToRgb(theme.methodColors.patch)}, 0.1);
      }

      .swagger-ui .opblock-head {
        border-color: ${theme.methodColors.head};
        background: rgba(${hexToRgb(theme.methodColors.head)}, 0.1);
      }

      .swagger-ui .opblock-options {
        border-color: ${theme.methodColors.options};
        background: rgba(${hexToRgb(theme.methodColors.options)}, 0.1);
      }

      .swagger-ui .opblock-summary-method {
        background-color: ${theme.primaryColor};
      }

      .swagger-ui .opblock-summary-path {
        color: ${theme.textColor};
      }

      .swagger-ui .parameter__name {
        color: ${theme.textColor};
      }

      .swagger-ui .parameter__type {
        color: ${theme.secondaryColor};
      }

      .swagger-ui input[type=text], 
      .swagger-ui textarea {
        border: 1px solid ${theme.primaryColor}40;
      }

      .swagger-ui input[type=text]:focus, 
      .swagger-ui textarea:focus {
        border: 1px solid ${theme.primaryColor};
      }

      /* 自定义按钮样式 */
      button[copy="true"] {
        background-color: ${theme.primaryColor} !important;
      }

      button[copy="true"]:hover {
        background-color: ${adjustColor(theme.primaryColor, -20)} !important;
      }

      /* 自定义表单区域 */
      #xxcaibi {
        background-color: ${theme.navBgColor};
        border: 1px solid ${adjustColor(theme.backgroundColor, -10)};
      }

      .xxcaibi-label {
        color: ${theme.textColor};
      }

      .xxcaibi-input {
        border: 1px solid ${adjustColor(theme.backgroundColor, -10)};
        background-color: ${theme.backgroundColor};
        color: ${theme.textColor};
      }

      .xxcaibi-input:focus {
        border-color: ${theme.primaryColor};
        box-shadow: 0 0 0 3px ${theme.primaryColor}40;
      }
    `;

    // 更新主题选择器样式
    const themeSelector = document.querySelector('.theme-selector');
    if (themeSelector) {
      themeSelector.style.backgroundColor = theme.navBgColor;
      themeSelector.style.color = theme.textColor;
      themeSelector.querySelector('select').style.borderColor = adjustColor(theme.backgroundColor, -10);
    }
  }

  // 辅助函数：将十六进制颜色转换为RGB
  function hexToRgb(hex) {
    const shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
    hex = hex.replace(shorthandRegex, (m, r, g, b) => r + r + g + g + b + b);
    
    const result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(hex);
    return result 
      ? `${parseInt(result[1], 16)}, ${parseInt(result[2], 16)}, ${parseInt(result[3], 16)}`
      : '0, 0, 0';
  }

  // 辅助函数：调整颜色亮度
  function adjustColor(color, percent) {
    const num = parseInt(color.replace('#', ''), 16),
      amt = Math.round(2.55 * percent),
      R = (num >> 16) + amt,
      G = (num >> 8 & 0x00FF) + amt,
      B = (num & 0x0000FF) + amt;
    
    return '#' + (
      0x1000000 +
      (R < 255 ? (R < 0 ? 0 : R) : 255) * 0x10000 +
      (G < 255 ? (G < 0 ? 0 : G) : 255) * 0x100 +
      (B < 255 ? (B < 0 ? 0 : B) : 255)
    ).toString(16).slice(1);
  }

  // 在页面加载完成后初始化主题选择器
  window.addEventListener('load', function() {
    // 等待Swagger UI加载完成
    const checkSwaggerLoaded = setInterval(function() {
      if (window.ui) {
        clearInterval(checkSwaggerLoaded);
        setTimeout(createThemeSelector, 500); // 给Swagger UI一些时间完成渲染
      }
    }, 100);
  });
})(); 