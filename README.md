# 双人协作爱心网页

一个基于Flask + SocketIO的双人实时协作网页，支持异地用户通过输入配对指令触发浪漫的爱心动画。包含完整的用户注册、登录系统，支持实时WebSocket通信。

## ✨ 功能特性

### 核心功能
- 🔐 **用户认证系统**：完整的注册、登录、登出功能
- 💬 **实时协作**：基于WebSocket的异地实时通信
- 💕 **爱心动画**：配对成功后触发精美爱心动画和粒子特效
- 🎯 **指令匹配**：预设多种配对指令（心动+信号、我+你等）
- 🏠 **房间机制**：通过房间码实现多组用户隔离协作
- 📱 **响应式设计**：完美适配桌面端和移动端

### 技术亮点
- ⚡ **毫秒级响应**：WebSocket长连接，延迟降至毫秒级
- 🔒 **安全认证**：密码加密存储、Session管理、CSRF保护
- 🎨 **现代UI**：渐变背景、卡片式设计、流畅动画
- 🌐 **易于部署**：提供完整的Nginx + Systemd部署方案

## 📋 技术栈

### 后端
- **Flask** - 轻量级Web框架
- **Flask-SocketIO** - WebSocket实时通信
- **Flask-Login** - 用户会话管理
- **Flask-SQLAlchemy** - ORM数据库操作
- **Flask-WTF** - 表单验证
- **SQLite** - 轻量级数据库（可替换为MySQL/PostgreSQL）
- **Eventlet** - 异步网络处理

### 前端
- **HTML5** - 语义化标签
- **CSS3** - 响应式布局、动画效果
- **JavaScript (ES6+)** - 原生JS，无框架依赖
- **Socket.IO Client** - WebSocket客户端

### 部署
- **Nginx** - 反向代理、静态文件服务
- **Systemd** - 进程守护、自动重启
- **Python虚拟环境** - 依赖隔离

## 🚀 快速开始

### 本地开发

1. **克隆项目**
```bash
git clone <your-repo-url>
cd love-collaboration
```

2. **创建虚拟环境**
```bash
python -m venv venv
# Windows
venv\Scripts\activate
# Linux/Mac
source venv/bin/activate
```

3. **安装依赖**
```bash
pip install -r requirements.txt
```

4. **初始化数据库**
```bash
python -c "from app import init_db; init_db()"
```

5. **启动应用**
```bash
python app.py
```

6. **访问应用**
打开浏览器访问：http://localhost:5000

### 生产环境部署

#### 方法1：使用自动部署脚本（推荐）

```bash
# 上传项目到服务器
scp -r love-collaboration user@server:/tmp/

# 登录服务器
ssh user@server

# 运行部署脚本
cd /tmp/love-collaboration
sudo bash deploy/deploy.sh
```

#### 方法2：手动部署

1. **安装系统依赖**
```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv nginx
```

2. **创建项目目录**
```bash
sudo mkdir -p /var/www/love-collaboration
sudo chown $USER:$USER /var/www/love-collaboration
```

3. **复制项目文件**
```bash
cp -r . /var/www/love-collaboration/
cd /var/www/love-collaboration
```

4. **创建虚拟环境并安装依赖**
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

5. **初始化数据库**
```bash
export FLASK_APP=app.py
python -c "from app import init_db; init_db()"
```

6. **配置Systemd服务**
```bash
sudo cp deploy/love-collaboration.service /etc/systemd/system/
# 编辑服务文件，修改路径
sudo vim /etc/systemd/system/love-collaboration.service
sudo systemctl daemon-reload
sudo systemctl enable love-collaboration
sudo systemctl start love-collaboration
```

7. **配置Nginx**
```bash
sudo cp deploy/nginx.conf /etc/nginx/sites-available/love-collaboration
# 编辑配置文件，修改域名和路径
sudo vim /etc/nginx/sites-available/love-collaboration
sudo ln -s /etc/nginx/sites-available/love-collaboration /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

8. **配置防火墙**
```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5000/tcp
```

## 📖 项目结构

```
love-collaboration/
├── app.py                      # 主应用文件
├── models.py                   # 数据库模型
├── forms.py                    # 表单验证
├── requirements.txt            # Python依赖
├── README.md                   # 项目文档
│
├── deploy/                     # 部署配置
│   ├── nginx.conf             # Nginx配置
│   ├── love-collaboration.service  # Systemd服务配置
│   └── deploy.sh              # 自动部署脚本
│
├── templates/                  # HTML模板
│   ├── base.html              # 基础模板
│   ├── login.html             # 登录页面
│   ├── register.html          # 注册页面
│   ├── index.html             # 协作主页
│   ├── 404.html               # 404错误页
│   └── 500.html               # 500错误页
│
└── static/                     # 静态资源
    ├── css/
    │   └── style.css          # 主样式文件
    └── js/
        └── main.js            # 主JS文件
```

## 🔧 配置说明

### 应用配置（app.py）

```python
app.config['SECRET_KEY'] = secrets.token_hex(32)  # 会话密钥
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///users.db'  # 数据库URI
```

### 预设配对指令

在`app.py`中修改`PRESET_PAIRS`列表：

```python
PRESET_PAIRS = [
    {'pair': ['心动', '信号'], 'description': '心动信号'},
    {'pair': ['我', '你'], 'description': '我和你'},
    # 添加更多配对...
]
```

## 🎮 使用指南

### 1. 注册账号
- 访问注册页面，填写用户名、邮箱、密码
- 系统会实时验证用户名和邮箱是否可用
- 密码强度检测确保账户安全

### 2. 登录系统
- 使用用户名或邮箱登录
- 可选择"记住我"保持登录状态

### 3. 开始协作
- 登录后自动进入协作页面
- 系统生成6位房间码
- 将房间链接分享给TA

### 4. 输入指令
- 双方在各自页面输入配对指令
- 系统实时同步对方输入状态
- 匹配成功触发爱心动画

### 5. 分享房间
- 点击"分享"按钮复制链接
- 支持Web Share API（移动端）
- 也支持手动复制链接

## 🔐 安全特性

- ✅ 密码使用Werkzeug加密存储
- ✅ CSRF Token防止跨站请求伪造
- ✅ Session管理保持登录状态
- ✅ 输入验证防止SQL注入和XSS
- ✅ WebSocket房间隔离，数据安全
- ✅ Nginx安全头配置

## 📊 数据库结构

### Users表
| 字段 | 类型 | 说明 |
|------|------|------|
| id | Integer | 主键 |
| username | String(80) | 用户名（唯一） |
| email | String(120) | 邮箱（唯一） |
| password_hash | String(255) | 密码哈希 |
| nickname | String(80) | 昵称 |
| created_at | DateTime | 创建时间 |
| last_login | DateTime | 最后登录 |
| is_active | Boolean | 是否激活 |

## 🛠️ 常见问题

### 1. WebSocket连接失败
- 检查防火墙是否开放5000端口
- 确认Nginx配置正确（/socket.io路由）
- 查看后端日志：`journalctl -u love-collaboration -f`

### 2. 数据库错误
- 确保users.db文件有写入权限
- 检查SQLALCHEMY_DATABASE_URI配置
- 重新初始化数据库

### 3. 静态文件404
- 检查Nginx配置中的static路径
- 确认文件权限正确
- 重启Nginx：`sudo systemctl reload nginx`

### 4. 服务无法启动
- 查看服务状态：`systemctl status love-collaboration`
- 查看错误日志：`journalctl -u love-collaboration -n 50`
- 检查Python路径和虚拟环境路径

## 🔄 更新日志

### v1.0.0 (2025-01-18)
- ✨ 完整的用户注册登录系统
- ✨ WebSocket实时通信
- ✨ 房间机制和指令匹配
- ✨ 响应式设计
- 📝 完整的部署文档

## 📝 待办事项

- [ ] 支持用户自定义配对指令
- [ ] 添加用户头像上传功能
- [ ] 集成Redis支持分布式部署
- [ ] 添加协作历史记录
- [ ] 支持语音/视频通话
- [ ] 添加更多预设动画效果
- [ ] 移动端App开发

## 🤝 贡献指南

欢迎提交Issue和Pull Request！

1. Fork本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 详见 LICENSE 文件

## ❤️ 致谢

感谢所有为本项目做出贡献的开发者！

---

如有问题，欢迎提Issue或联系作者。
