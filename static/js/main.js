// ========== 全局工具函数 ==========

// 显示Flash消息
function showFlash(message, type = 'info') {
    const flashContainer = document.querySelector('.flash-messages');
    if (!flashContainer) return;
    
    const flashEl = document.createElement('div');
    flashEl.className = `flash-message flash-${type}`;
    
    const icon = type === 'success' ? '✓' : '✗';
    
    flashEl.innerHTML = `
        <span class="flash-icon">${icon}</span>
        ${message}
        <button class="flash-close" onclick="this.parentElement.remove()">×</button>
    `;
    
    flashContainer.appendChild(flashEl);
    
    // 5秒后自动消失
    setTimeout(() => {
        flashEl.style.opacity = '0';
        flashEl.style.transform = 'translateY(-10px)';
        setTimeout(() => flashEl.remove(), 300);
    }, 5000);
}

// 格式化日期时间
function formatDateTime(date) {
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    const seconds = String(d.getSeconds()).padStart(2, '0');
    
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

// 格式化相对时间
function formatRelativeTime(date) {
    const now = new Date();
    const past = new Date(date);
    const diffMs = now - past;
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHour = Math.floor(diffMin / 60);
    const diffDay = Math.floor(diffHour / 24);
    
    if (diffSec < 60) return '刚刚';
    if (diffMin < 60) return `${diffMin}分钟前`;
    if (diffHour < 24) return `${diffHour}小时前`;
    if (diffDay < 7) return `${diffDay}天前`;
    if (diffDay < 30) return `${Math.floor(diffDay / 7)}周前`;
    if (diffDay < 365) return `${Math.floor(diffDay / 30)}个月前`;
    return `${Math.floor(diffDay / 365)}年前`;
}

// 复制文本到剪贴板
async function copyToClipboard(text) {
    try {
        if (navigator.clipboard && navigator.clipboard.writeText) {
            await navigator.clipboard.writeText(text);
            showFlash('已复制到剪贴板', 'success');
            return true;
        } else {
            // 降级方案
            const textArea = document.createElement('textarea');
            textArea.value = text;
            textArea.style.position = 'fixed';
            textArea.style.left = '-999999px';
            document.body.appendChild(textArea);
            textArea.select();
            try {
                document.execCommand('copy');
                document.body.removeChild(textArea);
                showFlash('已复制到剪贴板', 'success');
                return true;
            } catch (err) {
                document.body.removeChild(textArea);
                throw err;
            }
        }
    } catch (err) {
        console.error('复制失败:', err);
        showFlash('复制失败，请手动复制', 'error');
        return false;
    }
}

// 防抖函数
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// 节流函数
function throttle(func, limit) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

// 生成随机ID
function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
}

// URL参数解析
function getUrlParams() {
    const params = {};
    const queryString = window.location.search.substring(1);
    const pairs = queryString.split('&');
    
    for (let i = 0; i < pairs.length; i++) {
        const pair = pairs[i].split('=');
        params[decodeURIComponent(pair[0])] = decodeURIComponent(pair[1] || '');
    }
    
    return params;
}

// 构建URL参数
function buildUrlParams(params) {
    return Object.keys(params)
        .map(key => encodeURIComponent(key) + '=' + encodeURIComponent(params[key]))
        .join('&');
}

// 本地存储封装
const storage = {
    set(key, value, expire = null) {
        const data = {
            value: value,
            expire: expire ? Date.now() + expire : null
        };
        localStorage.setItem(key, JSON.stringify(data));
    },
    
    get(key) {
        try {
            const item = localStorage.getItem(key);
            if (!item) return null;
            
            const data = JSON.parse(item);
            
            // 检查是否过期
            if (data.expire && Date.now() > data.expire) {
                localStorage.removeItem(key);
                return null;
            }
            
            return data.value;
        } catch (e) {
            console.error('读取本地存储失败:', e);
            return null;
        }
    },
    
    remove(key) {
        localStorage.removeItem(key);
    },
    
    clear() {
        localStorage.clear();
    }
};

// ========== 表单验证 ==========

// 验证邮箱
function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}

// 验证用户名
function validateUsername(username) {
    // 3-20位，支持字母、数字、下划线、中文
    const re = /^[a-zA-Z0-9_\u4e00-\u9fa5]{3,20}$/;
    return re.test(username);
}

// 验证密码强度
function validatePassword(password) {
    const result = {
        valid: true,
        strength: 0,
        messages: []
    };
    
    if (password.length < 6) {
        result.valid = false;
        result.messages.push('密码长度至少6位');
    } else {
        result.strength++;
    }
    
    if (password.length >= 8) {
        result.strength++;
    }
    
    if (/[A-Za-z]/.test(password)) {
        result.strength++;
    }
    
    if (/[0-9]/.test(password)) {
        result.strength++;
    }
    
    if (/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
        result.strength++;
    }
    
    if (!/[A-Za-z]/.test(password) || !/[0-9]/.test(password)) {
        result.valid = false;
        result.messages.push('密码必须包含字母和数字');
    }
    
    return result;
}

// ========== 动画效果 ==========

// 淡入动画
function fadeIn(element, duration = 300) {
    element.style.opacity = '0';
    element.style.display = 'block';
    element.style.transition = `opacity ${duration}ms ease`;
    
    // 强制重排
    element.offsetHeight;
    
    element.style.opacity = '1';
}

// 淡出动画
function fadeOut(element, duration = 300) {
    element.style.opacity = '1';
    element.style.display = 'block';
    element.style.transition = `opacity ${duration}ms ease`;
    
    setTimeout(() => {
        element.style.opacity = '0';
    }, 10);
    
    setTimeout(() => {
        element.style.display = 'none';
    }, duration);
}

// 滑入动画
function slideIn(element, direction = 'right', duration = 300) {
    const transforms = {
        right: 'translateX(100%)',
        left: 'translateX(-100%)',
        up: 'translateY(100%)',
        down: 'translateY(-100%)'
    };
    
    element.style.transform = transforms[direction];
    element.style.opacity = '0';
    element.style.display = 'block';
    element.style.transition = `all ${duration}ms ease`;
    
    // 强制重排
    element.offsetHeight;
    
    element.style.transform = 'translateX(0)';
    element.style.opacity = '1';
}

// 缩放动画
function scaleIn(element, duration = 300) {
    element.style.transform = 'scale(0)';
    element.style.opacity = '0';
    element.style.display = 'block';
    element.style.transition = `all ${duration}ms ease`;
    
    // 强制重排
    element.offsetHeight;
    
    element.style.transform = 'scale(1)';
    element.style.opacity = '1';
}

// ========== API请求封装 ==========

class ApiClient {
    constructor(baseURL = '') {
        this.baseURL = baseURL;
    }
    
    async request(url, options = {}) {
        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json'
            }
        };
        
        const mergedOptions = { ...defaultOptions, ...options };
        
        if (mergedOptions.body && typeof mergedOptions.body === 'object') {
            mergedOptions.body = JSON.stringify(mergedOptions.body);
        }
        
        try {
            const response = await fetch(this.baseURL + url, mergedOptions);
            
            // 处理非JSON响应
            const contentType = response.headers.get('content-type');
            if (!contentType || !contentType.includes('application/json')) {
                return response;
            }
            
            const data = await response.json();
            
            if (!response.ok) {
                throw new Error(data.message || '请求失败');
            }
            
            return data;
        } catch (error) {
            console.error('API请求失败:', error);
            throw error;
        }
    }
    
    get(url, options = {}) {
        return this.request(url, { ...options, method: 'GET' });
    }
    
    post(url, data, options = {}) {
        return this.request(url, { ...options, method: 'POST', body: data });
    }
    
    put(url, data, options = {}) {
        return this.request(url, { ...options, method: 'PUT', body: data });
    }
    
    delete(url, options = {}) {
        return this.request(url, { ...options, method: 'DELETE' });
    }
}

const api = new ApiClient();

// ========== 页面加载 ==========

document.addEventListener('DOMContentLoaded', function() {
    // 初始化所有Flash消息的自动消失
    const flashMessages = document.querySelectorAll('.flash-message');
    flashMessages.forEach((flash, index) => {
        setTimeout(() => {
            flash.style.opacity = '0';
            flash.style.transform = 'translateY(-10px)';
            setTimeout(() => flash.remove(), 300);
        }, 5000 + index * 500);
    });
    
    // 为所有输入框添加焦点效果
    const inputs = document.querySelectorAll('input[type="text"], input[type="email"], input[type="password"], textarea');
    inputs.forEach(input => {
        input.addEventListener('focus', function() {
            this.parentElement.classList.add('focused');
        });
        
        input.addEventListener('blur', function() {
            this.parentElement.classList.remove('focused');
        });
    });
    
    // 为所有按钮添加点击效果
    const buttons = document.querySelectorAll('.btn');
    buttons.forEach(button => {
        button.addEventListener('mousedown', function() {
            this.style.transform = 'scale(0.98)';
        });
        
        button.addEventListener('mouseup', function() {
            this.style.transform = 'scale(1)';
        });
        
        button.addEventListener('mouseleave', function() {
            this.style.transform = 'scale(1)';
        });
    });
});

// ========== 工具类 ==========

// 元素抖动
function shakeElement(element, duration = 500) {
    const keyframes = [
        { transform: 'translateX(0)' },
        { transform: 'translateX(-5px)' },
        { transform: 'translateX(5px)' },
        { transform: 'translateX(-5px)' },
        { transform: 'translateX(5px)' },
        { transform: 'translateX(0)' }
    ];
    
    const animation = element.animate(keyframes, {
        duration: duration,
        easing: 'ease-in-out'
    });
    
    return animation;
}

// 显示加载状态
function showLoading(element, originalText) {
    const loadingText = '加载中...';
    element.disabled = true;
    element.dataset.originalText = originalText || element.textContent;
    element.textContent = loadingText;
}

// 隐藏加载状态
function hideLoading(element) {
    element.disabled = false;
    element.textContent = element.dataset.originalText || '确定';
    delete element.dataset.originalText;
}

// 确认对话框
function confirm(message, callback) {
    if (window.confirm(message)) {
        callback();
    }
}

// 获取元素位置
function getElementPosition(element) {
    const rect = element.getBoundingClientRect();
    return {
        top: rect.top + window.scrollY,
        left: rect.left + window.scrollX,
        width: rect.width,
        height: rect.height
    };
}

// 滚动到元素
function scrollToElement(element, offset = 0, behavior = 'smooth') {
    const position = getElementPosition(element);
    window.scrollTo({
        top: position.top - offset,
        behavior: behavior
    });
}

// 检测移动设备
function isMobile() {
    return /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
}

// 检测触摸设备
function isTouchDevice() {
    return 'ontouchstart' in window || navigator.maxTouchPoints > 0;
}

// 获取视口尺寸
function getViewportSize() {
    return {
        width: window.innerWidth,
        height: window.innerHeight
    };
}

// 监听窗口大小变化
function onResize(callback) {
    window.addEventListener('resize', debounce(callback, 200));
}

// ========== 控制台 ==========

// 在开发模式下显示友好的控制台信息
if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') {
    console.log('%c❤️ 爱心协作', 'color: #ff4757; font-size: 20px; font-weight: bold;');
    console.log('%c开发模式已启用', 'color: #747d8c; font-size: 14px;');
    console.log('%c如有问题，请检查控制台错误信息', 'color: #ffa502; font-size: 12px;');
}

// 导出全局对象（如果使用模块系统）
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        showFlash,
        formatDateTime,
        formatRelativeTime,
        copyToClipboard,
        debounce,
        throttle,
        generateId,
        getUrlParams,
        buildUrlParams,
        storage,
        validateEmail,
        validateUsername,
        validatePassword,
        fadeIn,
        fadeOut,
        slideIn,
        scaleIn,
        ApiClient,
        api,
        shakeElement,
        showLoading,
        hideLoading,
        confirm,
        getElementPosition,
        scrollToElement,
        isMobile,
        isTouchDevice,
        getViewportSize,
        onResize
    };
}
