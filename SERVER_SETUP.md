# Ubuntu 22.04 服务器生产环境配置指南

> 本文档提供完整的 Ubuntu 22.04 服务器配置方案，适用于 HeartSync 应用的生产环境部署。

---

## 目录

1. [系统初始化](#系统初始化)
2. [用户和权限管理](#用户和权限管理)
3. [SSH 安全配置](#ssh-安全配置)
4. [防火墙配置](#防火墙配置)
5. [系统安全加固](#系统安全加固)
6. [基础服务安装](#基础服务安装)
7. [网络配置](#网络配置)
8. [Python 环境配置](#python-环境配置)
9. [数据库配置](#数据库配置)
10. [Nginx 配置](#nginx-配置)
11. [系统监控和日志](#系统监控和日志)
12. [备份策略](#备份策略)
13. [性能优化](#性能优化)
14. [维护手册](#维护手册)

---

## 系统初始化

### 1.1 更新系统

```bash
# 更新包列表
sudo apt update

# 升级已安装的包
sudo apt upgrade -y

# 安装系统更新
sudo apt dist-upgrade -y

# 清理不需要的包
sudo apt autoremove -y
sudo apt autoclean -y
```

### 1.2 设置主机名

```bash
# 设置主机名
sudo hostnamectl set-hostname heartsync-server

# 编辑 hosts 文件
sudo nano /etc/hosts

# 添加以下内容
127.0.0.1   localhost
127.0.1.1   heartsync-server
<服务器公网IP>   heartsync-server.example.com

# 验证主机名
hostname
hostname -f
```

### 1.3 设置时区

```bash
# 设置为 UTC 时区（推荐用于服务器）
sudo timedatectl set-timezone UTC

# 或设置为中国时区
sudo timedatectl set-timezone Asia/Shanghai

# 查看时区设置
timedatectl
```

### 1.4 配置系统语言

```bash
# 安装中文语言包（如果需要）
sudo apt install -y language-pack-zh-hans

# 生成语言环境
sudo locale-gen zh_CN.UTF-8

# 设置默认语言
sudo update-locale LANG=en_US.UTF-8

# 重新登录使设置生效
```

### 1.5 配置 NTP 时间同步

```bash
# 安装 NTP 服务
sudo apt install -y ntp

# 配置 NTP 服务器
sudo nano /etc/ntp.conf

# 推荐使用的 NTP 服务器（选择其中一个）
# 中国大陆：
# server ntp.aliyun.com iburst
# server cn.ntp.org.cn iburst
# 全球：
# server 0.pool.ntp.org iburst
# server 1.pool.ntp.org iburst
# server 2.pool.ntp.org iburst

# 启动 NTP 服务
sudo systemctl enable ntp
sudo systemctl start ntp

# 验证时间同步
ntpq -p
timedatectl
```

---

## 用户和权限管理

### 2.1 创建部署用户

```bash
# 创建专门的应用部署用户
sudo adduser deploy

# 将用户添加到 sudo 组（允许执行 sudo 命令）
sudo usermod -aG sudo deploy

# 创建应用运行用户（www-data 用于 Web 服务）
sudo adduser --system --group --home /var/www www-data

# 验证用户
id deploy
id www-data
```

### 2.2 配置 sudo 权限

```bash
# 编辑 sudoers 文件（使用 visudo 更安全）
sudo visudo

# 在文件末尾添加以下内容（允许 deploy 用户执行 sudo 命令时不需要密码）
deploy ALL=(ALL) NOPASSWD:ALL

# 或者更严格的配置（仅允许特定命令）
# deploy ALL=(ALL) NOPASSWD:/usr/bin/systemctl restart heart_sync, \
#                               /usr/bin/systemctl reload nginx, \
#                               /usr/bin/apt-get update, \
#                               /usr/bin/apt-get upgrade

# 保存并退出（Ctrl+O, Enter, Ctrl+X）
```

### 2.3 配置 SSH 密钥认证

```bash
# 切换到部署用户
su - deploy

# 创建 .ssh 目录
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# 生成 SSH 密钥对
ssh-keygen -t ed25519 -b 4096 -C "deploy@heartsync-server" -f ~/.ssh/id_ed25519

# 将公钥添加到 authorized_keys
cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# 退出到 root 用户
exit

# 将私钥复制到本地电脑（用于免密登录）
# 在本地电脑上执行：
# ssh-copy-id -i ~/.ssh/id_ed25519 deploy@<服务器IP>

# 或手动复制公钥到本地
cat /home/deploy/.ssh/id_ed25519.pub
```

---

## SSH 安全配置

### 3.1 修改 SSH 端口

```bash
# 编辑 SSH 配置文件
sudo nano /etc/ssh/sshd_config

# 修改以下配置
Port 2222                    # 改为非默认端口（如 2222）
PermitRootLogin no            # 禁止 root 登录
PasswordAuthentication no      # 禁用密码认证（仅允许密钥）
PubkeyAuthentication yes       # 启用公钥认证
MaxAuthTries 3              # 最大认证尝试次数
ClientAliveInterval 300       # 客户端保活间隔（秒）
ClientAliveCountMax 2        # 最大保活次数
X11Forwarding no             # 禁用 X11 转发
AllowTcpForwarding no         # 禁用 TCP 转发
AllowAgentForwarding no       # 禁用代理转发
GatewayPorts no              # 禁用网关端口
UseDNS no                   # 禁用 DNS 解析（提高连接速度）

# 限制只允许特定用户登录（可选）
# AllowUsers deploy
# 或
# AllowGroups deploy

# 保存并退出
```

### 3.2 重启 SSH 服务

```bash
# 测试 SSH 配置是否正确
sudo sshd -t

# 重启 SSH 服务
sudo systemctl restart sshd

# 设置防火墙规则（在新端口允许 SSH）
sudo ufw allow 2222/tcp

# 验证 SSH 状态
sudo systemctl status sshd

# 在本地电脑测试新端口连接
ssh -p 2222 deploy@<服务器IP>
```

### 3.3 配置 SSH 客户端（本地电脑）

```bash
# 在本地电脑的 ~/.ssh/config 文件中添加
nano ~/.ssh/config

# 添加以下内容
Host heartsync
    HostName <服务器IP>
    Port 2222
    User deploy
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3

# 现在可以使用简化命令连接
ssh heartsync
```

---

## 防火墙配置

### 4.1 配置 UFW 防火墙

```bash
# 安装 UFW（如果未安装）
sudo apt install -y ufw

# 设置默认策略
sudo ufw default deny incoming          # 默认拒绝所有入站连接
sudo ufw default allow outgoing          # 默认允许所有出站连接

# 允许 SSH 连接（使用自定义端口）
sudo ufw allow 2222/tcp

# 允许 HTTP 和 HTTPS
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# 允许应用端口（如果需要直接访问）
# sudo ufw allow 5000/tcp comment 'HeartSync App'

# 允许特定 IP 访问管理端口（可选）
# sudo ufw allow from <你的IP> to any port 8080

# 启用防火墙
sudo ufw enable

# 查看防火墙状态
sudo ufw status verbose

# 查看防火墙规则编号
sudo ufw status numbered

# 删除规则（如果需要）
# sudo ufw delete <规则编号>
```

### 4.2 安装和配置 Fail2ban

```bash
# 安装 Fail2ban
sudo apt install -y fail2ban

# 创建自定义配置
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo nano /etc/fail2ban/jail.local

# 添加以下配置
[DEFAULT]
# 封禁时间（秒）
bantime = 3600
# 查找时间窗口（秒）
findtime = 600
# 最大失败次数
maxretry = 5
# 忽略 IP
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

# 启动 Fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# 查看状态
sudo fail2ban-client status
sudo fail2ban-client status sshd

# 查看被封禁的 IP
sudo fail2ban-client set sshd banip
sudo fail2ban-client get sshd banip

# 解封 IP
sudo fail2ban-client set sshd unbanip <IP地址>
```

---

## 系统安全加固

### 5.1 配置系统安全参数

```bash
# 编辑系统安全配置
sudo nano /etc/sysctl.conf

# 添加或修改以下内容
# 网络安全
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# 防止 SYN 攻击
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# 优化 TCP 连接
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_tw_buckets = 4000
net.ipv4.tcp_tw_reuse = 1

# 增加文件描述符限制
fs.file-max = 65535

# 保存并退出
```

### 5.2 应用系统配置

```bash
# 应用 sysctl 配置
sudo sysctl -p

# 验证配置
sudo sysctl -a | grep -E "tcp|ip_forward"
```

### 5.3 配置文件描述符限制

```bash
# 编辑 limits 配置
sudo nano /etc/security/limits.conf

# 添加以下内容
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535

# 保存并退出

# 创建 systemd 覆盖目录
sudo mkdir -p /etc/systemd/system.conf.d

# 创建限制配置
sudo nano /etc/systemd/system.conf.d/limits.conf

# 添加以下内容
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535

# 重新加载 systemd
sudo systemctl daemon-reload

# 验证配置
ulimit -n
```

### 5.4 配置自动安全更新

```bash
# 安装自动安全更新工具
sudo apt install -y unattended-upgrades

# 配置自动更新
sudo dpkg-reconfigure -plow unattended-upgrades

# 或手动编辑配置文件
sudo nano /etc/apt/apt.conf.d/50unattended-upgrades

# 修改以下配置
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}";
    "${distro_id}:${distro_codename}-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";

# 启用自动更新
sudo nano /etc/apt/apt.conf.d/20auto-upgrades

# 添加以下内容
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";

# 检查配置
sudo unattended-upgrades --dry-run --debug
```

---

## 基础服务安装

### 6.1 安装基础工具

```bash
# 安装常用工具
sudo apt install -y \
    curl \
    wget \
    git \
    vim \
    htop \
    tree \
    zip \
    unzip \
    rsync \
    jq \
    tmux \
    screen \
    net-tools \
    lsof \
    iotop \
    strace \
    tcpdump \
    ncdu \
    nc \
    telnet \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# 验证安装
curl --version
git --version
vim --version
```

### 6.2 安装 Python 环境

```bash
# 更新包列表
sudo apt update

# 安装 Python 3 和开发工具
sudo apt install -y python3 \
    python3-pip \
    python3-venv \
    python3-dev \
    build-essential \
    libssl-dev \
    libffi-dev \
    python3-setuptools

# 创建 Python 3 符号链接（如果需要）
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1

# 升级 pip
pip3 install --upgrade pip setuptools wheel

# 验证安装
python3 --version
pip3 --version
```

### 6.3 安装 Node.js（如果需要）

```bash
# 添加 Node.js 仓库
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -

# 安装 Node.js 和 npm
sudo apt install -y nodejs

# 验证安装
node --version
npm --version

# 配置 npm 镜像（可选，使用淘宝镜像）
npm config set registry https://registry.npmmirror.com
```

---

## 网络配置

### 7.1 配置静态 IP（可选）

```bash
# 查看网络接口
ip addr show

# 查看当前网络配置
ip route show

# 配置静态 IP（使用 netplan）
sudo nano /etc/netplan/00-installer-config.yaml

# 修改为以下内容（替换为你的网络配置）
network:
  ethernets:
    ens33:  # 替换为你的网卡名称
      addresses:
        - 192.168.1.100/24  # 静态 IP 和子网掩码
      routes:
        - to: default
          via: 192.168.1.1  # 网关
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
  version: 2

# 应用配置
sudo netplan apply

# 验证 IP 配置
ip addr show
ping -c 4 8.8.8.8
```

### 7.2 配置 DNS

```bash
# 编辑 resolv.conf
sudo nano /etc/systemd/resolved.conf

# 修改 DNS 服务器
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=1.0.0.1
Domains=~.

# 重启 DNS 解析服务
sudo systemctl restart systemd-resolved

# 测试 DNS 解析
nslookup google.com
```

### 7.3 配置主机名解析

```bash
# 编辑 hosts 文件
sudo nano /etc/hosts

# 添加本地域名解析
127.0.0.1   localhost heartsync.local
<服务器IP>   heartsync.example.com api.heartsync.example.com

# 验证解析
ping -c 2 heartsync.local
```

---

## Python 环境配置

### 8.1 创建项目目录结构

```bash
# 切换到部署用户
su - deploy

# 创建项目目录
sudo mkdir -p /var/www/heart_sync
sudo chown -R deploy:deploy /var/www/heart_sync
cd /var/www/heart_sync

# 创建子目录
mkdir -p {logs,backup,static,templates,data}

# 创建 Python 虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 升级 pip
pip install --upgrade pip setuptools wheel

# 退出虚拟环境
deactivate

# 退出到 root
exit
```

### 8.2 安装全局 Python 工具

```bash
# 安装全局 Python 工具（使用 --user）
pip3 install --user pipx

# 验证安装
pipx ensurepath

# 重新加载 PATH
source ~/.bashrc

# 使用 pipx 安装工具
pipx install black
pipx install isort
pipx install pylint
pipx install mypy

# 验证安装
black --version
isort --version
```

---

## 数据库配置

### 9.1 安装 PostgreSQL

```bash
# 安装 PostgreSQL
sudo apt install -y postgresql postgresql-contrib

# 启动 PostgreSQL 服务
sudo systemctl enable postgresql
sudo systemctl start postgresql

# 查看状态
sudo systemctl status postgresql

# 切换到 postgres 用户
sudo -u postgres psql

# 在 PostgreSQL 中执行以下命令
-- 创建数据库用户
CREATE USER heart_sync WITH PASSWORD 'your_strong_password_here';

-- 创建数据库
CREATE DATABASE heart_sync OWNER heart_sync;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE heart_sync TO heart_sync;

-- 退出
\q

# 配置 PostgreSQL 远程访问（如果需要）
sudo nano /etc/postgresql/14/main/pg_hba.conf

# 添加以下行（允许特定 IP 访问）
host    heart_sync    heart_sync    <你的IP>/32    scram-sha-256

# 配置 PostgreSQL 监听地址
sudo nano /etc/postgresql/14/main/postgresql.conf

# 修改以下行
listen_addresses = 'localhost'  # 或 '*' 允许所有地址

# 重启 PostgreSQL
sudo systemctl restart postgresql

# 测试连接
sudo -u postgres psql -d heart_sync -c "SELECT version();"
```

### 9.2 配置 PostgreSQL 自动备份

```bash
# 创建备份脚本
sudo nano /usr/local/bin/backup_postgres.sh

# 添加以下内容
#!/bin/bash

# PostgreSQL 备份脚本
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="heart_sync"
DB_USER="heart_sync"

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 执行备份
pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"

# 保留最近 7 天的备份
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +7 -delete

echo "Backup completed: ${DB_NAME}_${DATE}.sql.gz"

# 保存并退出

# 设置执行权限
sudo chmod +x /usr/local/bin/backup_postgres.sh

# 配置定时任务（每天凌晨 2 点备份）
sudo crontab -e

# 添加以下行
0 2 * * * /usr/local/bin/backup_postgres.sh >> /var/log/postgresql_backup.log 2>&1

# 验证定时任务
sudo crontab -l
```

### 9.3 或者使用 SQLite（开发环境）

```bash
# SQLite 已默认安装，无需额外配置

# 安装 SQLite 工具
sudo apt install -y sqlite3

# 验证安装
sqlite3 --version

# 创建数据库目录
sudo mkdir -p /var/www/heart_sync/data
sudo chown -R www-data:www-data /var/www/heart_sync/data

# 测试数据库创建
sudo -u www-data sqlite3 /var/www/heart_sync/data/heartsync.db "CREATE TABLE test (id INTEGER);"
```

---

## Nginx 配置

### 10.1 安装 Nginx

```bash
# 安装 Nginx
sudo apt install -y nginx

# 启动 Nginx
sudo systemctl enable nginx
sudo systemctl start nginx

# 查看状态
sudo systemctl status nginx

# 验证 Nginx 是否运行
curl http://localhost
```

### 10.2 配置 Nginx

```bash
# 创建站点配置
sudo nano /etc/nginx/sites-available/heart_sync

# 添加以下内容
# HeartSync 应用配置

# HTTP 服务器（重定向到 HTTPS）
server {
    listen 80;
    listen [::]:80;
    server_name heartsync.example.com www.heartsync.example.com;

    # Let's Encrypt 验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # 其他请求重定向到 HTTPS
    location / {
        return 301 https://$server_name$request_uri;
    }
}

# HTTPS 服务器
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name heartsync.example.com www.heartsync.example.com;

    # SSL 证书配置（使用 Let's Encrypt）
    ssl_certificate /etc/letsencrypt/live/heartsync.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/heartsync.example.com/privkey.pem;

    # SSL 安全配置
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_stapling on;
    ssl_stapling_verify on;

    # 安全头部
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # 日志配置
    access_log /var/log/nginx/heart_sync_access.log;
    error_log /var/log/nginx/heart_sync_error.log warn;

    # 客户端上传大小限制
    client_max_body_size 10M;
    client_body_timeout 60s;
    client_header_timeout 60s;

    # 静态文件
    location /static {
        alias /var/www/heart_sync/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # 健康检查端点
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # WebSocket 支持
    location /socket.io/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
        proxy_read_timeout 3600s;
    }

    # 应用代理
    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_redirect off;
        proxy_buffering off;
    }

    # 禁止访问隐藏文件
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}

# 保存并退出
```

### 10.3 启用站点配置

```bash
# 创建符号链接
sudo ln -sf /etc/nginx/sites-available/heart_sync /etc/nginx/sites-enabled/

# 删除默认站点
sudo rm -f /etc/nginx/sites-enabled/default

# 测试 Nginx 配置
sudo nginx -t

# 重启 Nginx
sudo systemctl restart nginx

# 验证配置
sudo nginx -T | grep -A 20 "server_name heartsync"
```

### 10.4 配置 SSL 证书（Let's Encrypt）

```bash
# 安装 Certbot
sudo apt install -y certbot python3-certbot-nginx

# 创建证书目录
sudo mkdir -p /var/www/certbot

# 获取证书（自动配置 Nginx）
sudo certbot --nginx -d heartsync.example.com -d www.heartsync.example.com

# 按提示输入邮箱并同意条款

# 或者手动获取证书
sudo certbot certonly --nginx -d heartsync.example.com -d www.heartsync.example.com

# 测试自动续期
sudo certbot renew --dry-run

# 证书自动续期已自动配置，查看定时任务
sudo systemctl list-timers | grep certbot

# 证书位置
# /etc/letsencrypt/live/heartsync.example.com/fullchain.pem
# /etc/letsencrypt/live/heartsync.example.com/privkey.pem
```

### 10.5 优化 Nginx 性能

```bash
# 编辑 Nginx 主配置
sudo nano /etc/nginx/nginx.conf

# 修改以下参数
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;

events {
    worker_connections 4096;
    multi_accept on;
    use epoll;
}

http {
    # 基础配置
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # 缓冲区配置
    client_body_buffer_size 128k;
    client_max_body_size 10m;
    client_header_buffer_size 1k;
    large_client_header_buffers 4 16k;
    output_buffers 1 32k;
    postpone_output 1460;

    # 其他配置...
}

# 测试并重启 Nginx
sudo nginx -t
sudo systemctl restart nginx
```

---

## 系统监控和日志

### 11.1 配置日志轮转

```bash
# 创建应用日志轮转配置
sudo nano /etc/logrotate.d/heart_sync

# 添加以下内容
/var/www/heart_sync/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 www-data www-data
    sharedscripts
    postrotate
        systemctl reload heart_sync > /dev/null 2>&1 || true
    endscript
}

/var/log/nginx/heart_sync_*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 www-data adm
    sharedscripts
    postrotate
        [ -f /var/run/nginx.pid ] && kill -USR1 `cat /var/run/nginx.pid`
    endscript
}

# 测试日志轮转
sudo logrotate -f /etc/logrotate.conf
```

### 11.2 安装监控工具

```bash
# 安装系统监控工具
sudo apt install -y htop iotop nethogs sysstat

# 启用 sysstat
sudo systemctl enable sysstat
sudo systemctl start sysstat

# 配置 sysstat 采集间隔
sudo nano /etc/default/sysstat

# 修改为
ENABLED="true"
SADC_OPTIONS="-S DISK"

# 重启 sysstat
sudo systemctl restart sysstat

# 查看系统统计
sar -u 1 3
```

### 11.3 配置告警（可选）

```bash
# 创建简单告警脚本
sudo nano /usr/local/bin/check_system.sh

# 添加以下内容
#!/bin/bash

# 系统健康检查脚本

# 检查磁盘使用率
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "警告: 磁盘使用率 ${DISK_USAGE}%"
fi

# 检查内存使用
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
if [ "$MEM_USAGE" -gt 90 ]; then
    echo "警告: 内存使用率 ${MEM_USAGE}%"
fi

# 检查 CPU 负载
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
LOAD_MAX=$(nproc)
if (( $(echo "$LOAD_AVG > $LOAD_MAX" | bc -l) )); then
    echo "警告: CPU 负载 ${LOAD_AVG}（核心数: $LOAD_MAX）"
fi

# 检查服务状态
if ! systemctl is-active --quiet nginx; then
    echo "警告: Nginx 服务未运行"
fi

if ! systemctl is-active --quiet heart_sync; then
    echo "警告: HeartSync 服务未运行"
fi

# 保存并退出

# 设置执行权限
sudo chmod +x /usr/local/bin/check_system.sh

# 添加到定时任务（每 5 分钟检查一次）
sudo crontab -e

# 添加以下行
*/5 * * * * /usr/local/bin/check_system.sh >> /var/log/system_check.log 2>&1
```

---

## 备份策略

### 12.1 创建完整备份脚本

```bash
# 创建备份脚本
sudo nano /usr/local/bin/backup_heartsync.sh

# 添加以下内容
#!/bin/bash

# HeartSync 完整备份脚本

BACKUP_DIR="/var/backups/heart_sync"
PROJECT_DIR="/var/www/heart_sync"
DATE=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=7

# 创建备份目录
mkdir -p "$BACKUP_DIR"

# 备份数据库
if [ -f "$PROJECT_DIR/data/heartsync.db" ]; then
    cp "$PROJECT_DIR/data/heartsync.db" "$BACKUP_DIR/database_$DATE.db"
    echo "数据库已备份"
fi

# 备份应用代码
cd /var/www
tar -czf "$BACKUP_DIR/code_$DATE.tar.gz" heart_sync --exclude='venv' --exclude='*.pyc' --exclude='__pycache__'
echo "代码已备份"

# 备份配置文件
cp "$PROJECT_DIR/.env.production" "$BACKUP_DIR/config_$DATE.env" 2>/dev/null || true
echo "配置已备份"

# 清理旧备份
find "$BACKUP_DIR" -name "*.db" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
find "$BACKUP_DIR" -name "*.env" -mtime +$RETENTION_DAYS -delete
echo "旧备份已清理"

echo "备份完成: $DATE"

# 保存并退出

# 设置执行权限
sudo chmod +x /usr/local/bin/backup_heartsync.sh

# 配置定时任务（每天凌晨 3 点备份）
sudo crontab -e

# 添加以下行
0 3 * * * /usr/local/bin/backup_heartsync.sh >> /var/log/heart_sync_backup.log 2>&1
```

### 12.2 远程备份（可选）

```bash
# 安装 rsync
sudo apt install -y rsync

# 配置 SSH 密钥到备份服务器
ssh-copy-id user@backup-server

# 创建远程备份脚本
sudo nano /usr/local/bin/backup_remote.sh

# 添加以下内容
#!/bin/bash

# 远程备份脚本

LOCAL_BACKUP_DIR="/var/backups/heart_sync"
REMOTE_SERVER="user@backup-server"
REMOTE_DIR="/backup/heart_sync"

# 同步到远程服务器
rsync -avz --delete "$LOCAL_BACKUP_DIR/" "$REMOTE_SERVER:$REMOTE_DIR/"

echo "远程备份完成: $(date)"

# 保存并退出

# 设置执行权限
sudo chmod +x /usr/local/bin/backup_remote.sh

# 添加到定时任务（每小时同步一次）
sudo crontab -e

# 添加以下行
0 * * * * /usr/local/bin/backup_remote.sh >> /var/log/remote_backup.log 2>&1
```

---

## 性能优化

### 13.1 优化系统性能

```bash
# 安装性能分析工具
sudo apt install -y perf linux-tools-generic

# 配置 CPU 性能模式
sudo apt install -y cpufrequtils
sudo cpufreq-set -g performance

# 查看当前 CPU 频率
cpufreq-info

# 配置 I/O 调度器（SSD 推荐 noop 或 deadline）
echo 'deadline' | sudo tee /sys/block/sda/queue/scheduler

# 永久配置 I/O 调度器
sudo nano /etc/default/grub

# 修改 GRUB_CMDLINE_LINUX_DEFAULT
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash elevator=deadline"

# 更新 GRUB
sudo update-grub
```

### 13.2 优化 PostgreSQL 性能

```bash
# 编辑 PostgreSQL 配置
sudo nano /etc/postgresql/14/main/postgresql.conf

# 添加或修改以下参数
# 连接设置
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
maintenance_work_mem = 64MB
work_mem = 16MB

# 查询优化
random_page_cost = 1.1
effective_io_concurrency = 200

# WAL 设置
wal_buffers = 16MB
min_wal_size = 1GB
max_wal_size = 4GB
checkpoint_completion_target = 0.9

# 日志设置
log_min_duration_statement = 1000  # 记录超过 1 秒的查询

# 保存并退出

# 重启 PostgreSQL
sudo systemctl restart postgresql
```

### 13.3 创建 systemd 服务

```bash
# 创建 systemd 服务文件
sudo nano /etc/systemd/system/heart_sync.service

# 添加以下内容
[Unit]
Description=HeartSync Application
After=network.target postgresql.service nginx.service

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=/var/www/heart_sync
Environment="PATH=/var/www/heart_sync/venv/bin"
ExecStart=/var/www/heart_sync/venv/bin/gunicorn \
    -w 4 \
    -b 127.0.0.1:5000 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    app:app
ExecReload=/bin/kill -s HUP $MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target

# 保存并退出

# 重载 systemd
sudo systemctl daemon-reload

# 启用服务
sudo systemctl enable heart_sync

# 启动服务
sudo systemctl start heart_sync

# 查看状态
sudo systemctl status heart_sync

# 查看日志
sudo journalctl -u heart_sync -f
```

---

## 维护手册

### 14.1 日常维护任务

```bash
# 查看系统负载
htop

# 查看磁盘使用
df -h
ncdu

# 查看内存使用
free -h

# 查看网络连接
ss -tuln
nethogs

# 查看日志
sudo journalctl -u heart_sync -f
sudo tail -f /var/log/nginx/heart_sync_error.log

# 重启服务
sudo systemctl restart heart_sync
sudo systemctl reload nginx

# 查看定时任务
sudo crontab -l
```

### 14.2 更新系统

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

### 14.3 故障排除

```bash
# 服务无法启动
sudo systemctl status heart_sync
sudo journalctl -u heart_sync -n 50

# 端口被占用
sudo lsof -i :5000
sudo netstat -tuln | grep 5000

# 杀死占用端口的进程
sudo kill -9 <PID>

# 检查防火墙
sudo ufw status
sudo ufw allow <端口>

# 检查 DNS
nslookup google.com
dig google.com

# 测试网络连接
ping -c 4 8.8.8.8
curl -I http://google.com

# 检查系统资源
vmstat 1 5
iostat -x 1 5
sar -u 1 5
```

### 14.4 安全检查

```bash
# 查看登录日志
sudo last
sudo lastb

# 查看失败的登录尝试
sudo grep "Failed password" /var/log/auth.log | tail -20

# 查看当前登录用户
who
w

# 检查开放端口
sudo ss -tuln
sudo netstat -tuln

# 查看进程
ps aux
top
htop

# 检查磁盘 I/O
sudo iotop -o

# 检查 Fail2ban 状态
sudo fail2ban-client status
sudo fail2ban-client status sshd
```

---

## 快速参考

### 常用命令

```bash
# 服务管理
sudo systemctl start <service>      # 启动服务
sudo systemctl stop <service>       # 停止服务
sudo systemctl restart <service>    # 重启服务
sudo systemctl reload <service>     # 重载配置
sudo systemctl enable <service>    # 开机自启
sudo systemctl disable <service>   # 禁用开机自启
sudo systemctl status <service>    # 查看状态

# 日志查看
sudo journalctl -u <service> -f  # 实时查看服务日志
sudo tail -f /path/to/log       # 实时查看文件日志

# 防火墙管理
sudo ufw enable                  # 启用防火墙
sudo ufw disable                 # 禁用防火墙
sudo ufw status                  # 查看状态
sudo ufw allow <port>           # 允许端口
sudo ufw deny <port>           # 拒绝端口

# 系统监控
htop                            # 系统监控
iostat                          # I/O 统计
vmstat                          # 虚拟内存统计
df -h                           # 磁盘使用
free -h                         # 内存使用
```

### 重要文件位置

```
# 应用
/var/www/heart_sync/              # 应用目录
/var/www/heart_sync/logs/        # 应用日志
/var/backups/heart_sync/          # 备份目录

# Nginx
/etc/nginx/                       # Nginx 配置
/etc/nginx/sites-available/        # 站点配置
/etc/nginx/sites-enabled/          # 启用的站点
/var/log/nginx/                  # Nginx 日志

# PostgreSQL
/etc/postgresql/14/main/         # PostgreSQL 配置
/var/lib/postgresql/14/           # 数据目录
/var/log/postgresql/              # PostgreSQL 日志

# 系统日志
/var/log/syslog                  # 系统日志
/var/log/auth.log                # 认证日志
/var/log/kern.log                # 内核日志
/var/log/lastlog                # 最后登录日志

# 服务
/etc/systemd/system/             # systemd 服务配置
/etc/logrotate.d/               # 日志轮转配置
/etc/cron.*                    # 定时任务
```

### 端口和协议

```
SSH:        2222/tcp          # 自定义 SSH 端口
HTTP:       80/tcp            # HTTP
HTTPS:      443/tcp           # HTTPS
Flask App:  5000/tcp          # 应用内部端口（不对外开放）
PostgreSQL: 5432/tcp          # 数据库（仅本地）
```

---

## 总结

本配置指南提供了完整的 Ubuntu 22.04 服务器生产环境配置方案，包括：

✅ **系统初始化**: 更新、主机名、时区、时间同步
✅ **用户管理**: 部署用户、权限配置、SSH 密钥
✅ **SSH 安全**: 端口修改、密钥认证、访问控制
✅ **防火墙**: UFW 配置、Fail2ban 入侵防护
✅ **安全加固**: 系统参数、文件限制、自动更新
✅ **基础服务**: Python、Node.js、常用工具
✅ **网络配置**: 静态 IP、DNS、主机名解析
✅ **数据库**: PostgreSQL 安装、配置、备份
✅ **Web 服务器**: Nginx 配置、SSL 证书、性能优化
✅ **监控告警**: 日志轮转、系统监控、健康检查
✅ **备份策略**: 自动备份、远程备份、备份清理
✅ **性能优化**: 系统优化、数据库优化、服务配置

遵循本指南，你将获得一个安全、稳定、高性能的生产环境服务器。

---

## 下一步

1. 部署 HeartSync 应用到服务器
2. 配置 HTTPS 和 SSL 证书
3. 设置监控和告警系统
4. 定期备份和系统更新
5. 性能测试和优化

祝部署顺利！🚀
