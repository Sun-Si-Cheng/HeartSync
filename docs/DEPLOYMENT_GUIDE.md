# Ubuntu 22.04 服务器部署完整指南

本指南提供从零开始配置 Ubuntu 22.04 服务器并部署 HeartSync 应用的完整流程。

---

## 📋 目录

1. [准备阶段](#准备阶段)
2. [服务器初始化](#服务器初始化)
3. [应用部署](#应用部署)
4. [HTTPS 配置](#https-配置)
5. [验证和测试](#验证和测试)
6. [日常运维](#日常运维)

---

## 准备阶段

### 1.1 购买服务器

推荐配置：
- **CPU**: 2 核心及以上
- **内存**: 4GB 及以上
- **磁盘**: 40GB SSD
- **系统**: Ubuntu 22.04 LTS

推荐云服务商：
- 阿里云: https://www.aliyun.com
- 腾讯云: https://cloud.tencent.com
- 华为云: https://www.huaweicloud.com
- AWS: https://aws.amazon.com
- DigitalOcean: https://www.digitalocean.com

### 1.2 准备本地环境

在本地电脑上安装必要的工具：

**Windows:**
```powershell
# 安装 Git
# 下载: https://git-scm.com/download/win

# 安装 SSH 客户端（Windows 10/11 已内置）
# 测试: ssh --version

# 生成 SSH 密钥
ssh-keygen -t ed25519 -b 4096 -C "your_email@example.com"
```

**macOS/Linux:**
```bash
# 安装 Git
sudo apt install git  # Ubuntu/Debian
brew install git    # macOS

# 生成 SSH 密钥
ssh-keygen -t ed25519 -b 4096 -C "your_email@example.com"

# 查看公钥
cat ~/.ssh/id_ed25519.pub
```

---

## 服务器初始化

### 2.1 连接服务器

```bash
# 使用密码连接（首次）
ssh root@<服务器IP>

# 使用密钥连接
ssh -i ~/.ssh/id_ed25519 root@<服务器IP>
```

### 2.2 运行初始化脚本

```bash
# 下载初始化脚本
wget https://raw.githubusercontent.com/your-repo/HeartSync/main/scripts/init_server.sh

# 或使用 git 克隆
git clone https://github.com/your-repo/HeartSync.git
cd HeartSync

# 运行初始化脚本
sudo bash scripts/init_server.sh
```

### 2.3 初始化脚本说明

脚本会依次执行以下步骤：

1. ✅ 更新系统
2. ✅ 设置主机名
3. ✅ 设置时区
4. ✅ 安装基础工具
5. ✅ 配置 NTP
6. ✅ 创建部署用户
7. ✅ 配置 SSH
8. ✅ 配置防火墙
9. ✅ 配置 Fail2ban
10. ✅ 配置系统安全参数
11. ✅ 安装 Python 环境
12. ✅ 安装 PostgreSQL
13. ✅ 安装 Nginx
14. ✅ 配置项目目录
15. ✅ 配置日志轮转
16. ✅ 安装监控工具
17. ✅ 配置自动备份
18. ✅ 配置健康检查

**预计耗时**: 10-15 分钟

### 2.4 记录重要信息

脚本运行完成后，会显示以下信息，请务必保存：

```
========================================
  服务器初始化完成！
========================================

重要信息：
  部署用户: deploy
  SSH 端口: 2222
  主机名: heartsync-server
  时区: Asia/Shanghai

SSH 公钥：
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... deploy@heartsync-server

数据库信息：
  数据库: heart_sync
  用户: heart_sync
  密码: heartsync123
```

### 2.5 配置本地 SSH

编辑本地 `~/.ssh/config` 文件：

```bash
nano ~/.ssh/config
```

添加以下内容：

```
Host heartsync
    HostName <服务器IP>
    Port 2222
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
```

现在可以使用简化命令连接：

```bash
ssh heartsync
```

---

## 应用部署

### 3.1 克隆代码到服务器

```bash
# SSH 连接到服务器
ssh heartsync

# 进入项目目录
cd /var/www/heart_sync

# 克隆代码（首次部署）
git clone https://github.com/your-repo/HeartSync.git .

# 或者上传代码（如果代码在本地）
# 在本地执行：
rsync -avz --exclude='venv' --exclude='*.pyc' \
    ./ heartsync:/var/www/heart_sync/

# 在服务器上执行：
cd /var/www/heart_sync
```

### 3.2 配置环境变量

```bash
# 复制环境配置示例
cp .env.example .env.production

# 编辑配置
nano .env.production
```

修改以下关键配置：

```bash
# 应用环境
APP_ENV=production

# Flask配置
FLASK_APP=app.py
FLASK_ENV=production
SECRET_KEY=<生成的强密钥>
DEBUG=False

# 数据库配置
DATABASE_URL=postgresql://heart_sync:heartsync123@localhost:5432/heart_sync

# 服务器配置
HOST=0.0.0.0
PORT=5000

# 日志配置
LOG_LEVEL=INFO
LOG_FILE=logs/app.log

# CORS配置（生产环境必须设置具体域名）
CORS_ALLOWED_ORIGINS=https://yourdomain.com
```

生成强密钥：

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

### 3.3 安装依赖

```bash
# 激活虚拟环境
source venv/bin/activate

# 安装依赖
pip install --upgrade pip
pip install gunicorn
pip install -r requirements.txt

# 验证安装
pip list
```

### 3.4 初始化数据库

```bash
# 激活虚拟环境
source venv/bin/activate

# 初始化数据库
python -c "from app import app, db, init_db; app.app_context().push(); init_db()"

# 验证数据库
ls -la data/
```

### 3.5 运行部署脚本

```bash
# 切换到项目根目录
cd /var/www/heart_sync

# 运行部署脚本
sudo bash scripts/deploy_app.sh
```

部署脚本会自动完成：

1. ✅ 备份当前版本
2. ✅ 部署新版本
3. ✅ 配置环境
4. ✅ 安装依赖
5. ✅ 设置权限
6. ✅ 初始化数据库
7. ✅ 配置 systemd 服务
8. ✅ 启动服务
9. ✅ 健康检查

### 3.6 验证服务状态

```bash
# 检查应用服务
sudo systemctl status heart_sync

# 检查 Nginx 服务
sudo systemctl status nginx

# 查看应用日志
sudo journalctl -u heart_sync -f

# 查看错误日志
sudo tail -f /var/www/heart_sync/logs/app.log

# 测试健康检查
curl http://localhost:5000/health
```

---

## HTTPS 配置

### 4.1 准备域名

确保你已经拥有一个域名并已指向服务器 IP：

```bash
# 测试 DNS 解析
nslookup yourdomain.com
dig yourdomain.com +short
```

### 4.2 更新 Nginx 配置

```bash
# 编辑 Nginx 配置
sudo nano /etc/nginx/sites-available/heart_sync
```

修改 `server_name`：

```nginx
server_name yourdomain.com www.yourdomain.com;
```

测试并重载 Nginx：

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 4.3 获取 SSL 证书

```bash
# 安装 Certbot
sudo apt install certbot python3-certbot-nginx

# 创建验证目录
sudo mkdir -p /var/www/certbot

# 获取证书（自动配置）
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# 按提示输入邮箱并同意条款
```

Certbot 会自动：
1. 验证域名所有权
2. 获取 SSL 证书
3. 更新 Nginx 配置
4. 配置自动续期

### 4.4 验证 HTTPS

```bash
# 测试 HTTPS 连接
curl -I https://yourdomain.com

# 检查 SSL 证书有效期
echo | openssl s_client -connect yourdomain.com:443 2>/dev/null | openssl x509 -noout -dates
```

### 4.5 配置自动续期

Certbot 会自动配置证书续期，验证定时任务：

```bash
# 查看定时任务
sudo systemctl list-timers | grep certbot

# 手动测试续期
sudo certbot renew --dry-run
```

---

## 验证和测试

### 5.1 访问应用

在浏览器中访问：

```
http://yourdomain.com
或
https://yourdomain.com
```

### 5.2 功能测试

1. **用户注册**
   - 访问注册页面
   - 填写注册信息
   - 验证邮箱格式和密码强度

2. **用户登录**
   - 使用注册的账号登录
   - 验证登录功能

3. **协作功能**
   - 创建房间
   - 邀请另一个用户加入
   - 测试实时通信

4. **WebSocket 连接**
   - 打开浏览器开发者工具
   - 查看 Network → WS
   - 验证 WebSocket 连接状态

### 5.3 性能测试

使用 Apache Bench 进行压力测试：

```bash
# 安装 ab
sudo apt install apache2-utils

# 测试主页（100 个并发，共 1000 个请求）
ab -n 1000 -c 100 https://yourdomain.com/

# 测试 WebSocket 连接
curl -I https://yourdomain.com/socket.io/
```

### 5.4 安全测试

```bash
# 检查 SSL 配置
curl -I https://yourdomain.com | grep -i strict

# 检查安全头部
curl -I https://yourdomain.com

# 测试 HTTPS 重定向
curl -I http://yourdomain.com
```

---

## 日常运维

### 6.1 监控服务

```bash
# 实时监控系统资源
htop

# 查看磁盘使用
df -h

# 查看内存使用
free -h

# 查看网络连接
ss -tuln

# 查看进程
ps aux | grep heart_sync
```

### 6.2 查看日志

```bash
# 应用日志
sudo tail -f /var/www/heart_sync/logs/app.log

# Nginx 访问日志
sudo tail -f /var/log/nginx/heart_sync_access.log

# Nginx 错误日志
sudo tail -f /var/log/nginx/heart_sync_error.log

# 系统日志
sudo journalctl -f

# 特定服务日志
sudo journalctl -u heart_sync -f
sudo journalctl -u nginx -f
```

### 6.3 重启服务

```bash
# 重启应用
sudo systemctl restart heart_sync

# 重启 Nginx
sudo systemctl restart nginx

# 重启 PostgreSQL
sudo systemctl restart postgresql

# 重启所有服务
sudo systemctl restart heart_sync nginx postgresql
```

### 6.4 更新应用

```bash
# 切换到项目目录
cd /var/www/heart_sync

# 拉取最新代码
git pull origin main

# 或上传新代码
rsync -avz --exclude='venv' --exclude='*.pyc' \
    ./ heartsync:/var/www/heart_sync/

# 运行部署脚本
sudo bash scripts/deploy_app.sh
```

### 6.5 数据库备份

```bash
# 手动备份数据库
/usr/local/bin/backup_postgres.sh

# 查看备份文件
ls -lh /var/backups/postgresql/

# 恢复数据库（如需要）
gunzip < /var/backups/postgresql/heart_sync_20240122_120000.sql.gz | \
    sudo -u postgres psql heart_sync
```

### 6.6 检查防火墙

```bash
# 查看防火墙状态
sudo ufw status

# 查看详细规则
sudo ufw status verbose

# 查看规则编号
sudo ufw status numbered

# 添加规则
sudo ufw allow 8080/tcp

# 删除规则
sudo ufw delete 1
```

### 6.7 检查 Fail2ban

```bash
# 查看 Fail2ban 状态
sudo fail2ban-client status

# 查看 SSH 监控状态
sudo fail2ban-client status sshd

# 查看被封禁的 IP
sudo fail2ban-client get sshd banip

# 解封 IP
sudo fail2ban-client set sshd unbanip <IP地址>
```

### 6.8 系统更新

```bash
# 更新包列表
sudo apt update

# 查看可更新的包
apt list --upgradable

# 升级系统
sudo apt upgrade -y

# 清理
sudo apt autoremove -y
sudo apt autoclean -y

# 如果有内核更新，重启
sudo reboot
```

---

## 故障排除

### 应用无法启动

```bash
# 检查服务状态
sudo systemctl status heart_sync

# 查看详细日志
sudo journalctl -u heart_sync -n 50

# 检查端口占用
sudo lsof -i :5000
sudo ss -tuln | grep 5000

# 手动启动测试
source venv/bin/activate
python app.py
```

### 数据库连接失败

```bash
# 检查 PostgreSQL 状态
sudo systemctl status postgresql

# 测试连接
sudo -u postgres psql -d heart_sync -c "SELECT version();"

# 查看数据库日志
sudo tail -f /var/log/postgresql/postgresql-14-main.log

# 重启数据库
sudo systemctl restart postgresql
```

### Nginx 502 错误

```bash
# 检查应用是否运行
curl http://localhost:5000/health

# 检查 Nginx 配置
sudo nginx -t

# 查看 Nginx 错误日志
sudo tail -f /var/log/nginx/heart_sync_error.log

# 重启 Nginx
sudo systemctl restart nginx
```

### WebSocket 连接失败

```bash
# 检查 Nginx 配置
grep -A 10 "location /socket.io/" /etc/nginx/sites-available/heart_sync

# 测试 WebSocket 连接
wscat -c ws://yourdomain.com/socket.io/

# 查看应用日志
sudo tail -f /var/www/heart_sync/logs/app.log
```

---

## 总结

完成以上步骤后，你将拥有：

✅ **配置完整的生产环境服务器**
✅ **安全加固的 Ubuntu 22.04 系统**
✅ **部署的 HeartSync 应用**
✅ **HTTPS 和 SSL 证书**
✅ **自动备份和监控**
✅ **完整的日志记录**

---

## 下一步

- 配置域名和 DNS
- 设置监控告警
- 配置邮件通知
- 性能优化
- 高可用配置

---

## 需要帮助？

查看详细文档：
- [SERVER_SETUP.md](../SERVER_SETUP.md) - 服务器配置完整指南
- [DEPLOYMENT.md](../DEPLOYMENT.md) - CI/CD 和部署指南
- [QUICKSTART.md](../QUICKSTART.md) - 快速开始指南

提交问题：
- GitHub Issues
- Email Support
