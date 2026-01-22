# Ubuntu 22.04 服务器配置快速参考卡

> 本文档提供服务器配置、部署和运维的快速参考。

---

## 🖥️ 系统信息

### 基本信息
```bash
# 查看系统版本
lsb_release -a

# 查看内核版本
uname -a

# 查看系统架构
arch

# 查看运行时间
uptime

# 查看主机名
hostname
hostname -f

# 查看时区
timedatectl
```

### 资源监控
```bash
# CPU 和内存
htop
top
vmstat 1 5

# 磁盘使用
df -h
du -sh /var/www/heart_sync
ncdu

# I/O 监控
iostat -x 1 5
iotop -o

# 网络监控
nethogs
iftop
ss -tuln

# 系统负载
uptime
cat /proc/loadavg
```

---

## 🔐 安全配置

### SSH 配置
```bash
# 配置文件
/etc/ssh/sshd_config

# 关键配置
Port 2222                    # SSH 端口
PermitRootLogin no            # 禁止 root 登录
PasswordAuthentication no      # 禁用密码登录

# 重启 SSH
sudo systemctl restart sshd

# 测试连接
ssh -p 2222 deploy@server
```

### 防火墙 (UFW)
```bash
# 查看状态
sudo ufw status

# 允许端口
sudo ufw allow 2222/tcp      # SSH
sudo ufw allow 80/tcp         # HTTP
sudo ufw allow 443/tcp        # HTTPS

# 删除规则
sudo ufw delete allow 80/tcp

# 重置防火墙
sudo ufw reset
```

### Fail2ban
```bash
# 查看状态
sudo fail2ban-client status

# 查看 SSH 状态
sudo fail2ban-client status sshd

# 查看被封 IP
sudo fail2ban-client get sshd banip

# 解封 IP
sudo fail2ban-client set sshd unbanip <IP>

# 查看日志
sudo grep 'Ban' /var/log/fail2ban.log | tail -20
```

---

## 🗄️ 数据库 (PostgreSQL)

### 基本操作
```bash
# 连接数据库
sudo -u postgres psql
sudo -u postgres psql -d heart_sync

# 列出数据库
\l

# 切换数据库
\c heart_sync

# 列出表
\dt

# 查看表结构
\d users

# 执行 SQL
SELECT * FROM users;

# 退出
\q
```

### 数据库管理
```bash
# 备份数据库
sudo -u postgres pg_dump heart_sync > backup.sql

# 压缩备份
sudo -u postgres pg_dump heart_sync | gzip > backup.sql.gz

# 恢复数据库
sudo -u postgres psql heart_sync < backup.sql

# 恢复压缩备份
gunzip < backup.sql.gz | sudo -u postgres psql heart_sync

# 删除数据库
sudo -u postgres psql -c "DROP DATABASE heart_sync;"

# 创建数据库
sudo -u postgres psql -c "CREATE DATABASE heart_sync;"
```

### 性能优化
```bash
# 连接统计
SELECT count(*) FROM pg_stat_activity;

# 慢查询
SELECT query, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;

# 表大小
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🌐 Nginx

### 基本操作
```bash
# 配置目录
/etc/nginx/
/etc/nginx/sites-available/     # 可用站点
/etc/nginx/sites-enabled/        # 启用站点

# 测试配置
sudo nginx -t

# 重载配置
sudo systemctl reload nginx

# 重启服务
sudo systemctl restart nginx

# 查看状态
sudo systemctl status nginx

# 查看详细配置
sudo nginx -T
```

### 日志管理
```bash
# 访问日志
/var/log/nginx/access.log
/var/log/nginx/heart_sync_access.log

# 错误日志
/var/log/nginx/error.log
/var/log/nginx/heart_sync_error.log

# 实时查看
sudo tail -f /var/log/nginx/heart_sync_access.log

# 查看错误
sudo tail -f /var/log/nginx/heart_sync_error.log

# 分析日志
grep " 404 " /var/log/nginx/heart_sync_access.log | wc -l
grep " 500 " /var/log/nginx/heart_sync_access.log | wc -l
```

### SSL 证书
```bash
# 证书位置
/etc/letsencrypt/live/yourdomain.com/

# 证书文件
fullchain.pem     # 完整证书链
privkey.pem       # 私钥

# 获取证书
sudo certbot --nginx -d yourdomain.com

# 续期证书
sudo certbot renew

# 测试续期
sudo certbot renew --dry-run

# 查看证书信息
sudo certbot certificates
```

---

## 🐍 Python 应用

### 虚拟环境
```bash
# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate

# 退出虚拟环境
deactivate

# 安装包
pip install package

# 列出已安装包
pip list

# 导出依赖
pip freeze > requirements.txt

# 从文件安装
pip install -r requirements.txt
```

### Gunicorn
```bash
# 启动应用
gunicorn -w 4 -b 127.0.0.1:5000 app:app

# 查看帮助
gunicorn --help

# 常用参数
-w N           # 工作进程数
-b HOST:PORT   # 绑定地址
--timeout N    # 请求超时（秒）
--workers N    # Worker 数量
--log-level N  # 日志级别
```

### systemd 服务
```bash
# 服务文件
/etc/systemd/system/heart_sync.service

# 服务管理
sudo systemctl start heart_sync          # 启动
sudo systemctl stop heart_sync           # 停止
sudo systemctl restart heart_sync        # 重启
sudo systemctl reload heart_sync         # 重载
sudo systemctl enable heart_sync         # 开机自启
sudo systemctl disable heart_sync        # 禁用自启

# 查看状态
sudo systemctl status heart_sync

# 查看日志
sudo journalctl -u heart_sync -f

# 查看最近日志
sudo journalctl -u heart_sync -n 100
```

---

## 📊 监控和日志

### 应用日志
```bash
# 日志目录
/var/www/heart_sync/logs/

# 应用日志
/var/www/heart_sync/logs/app.log

# 部署日志
/var/www/heart_sync/logs/deploy_*.log

# 健康检查日志
/var/www/heart_sync/logs/health_check_*.log

# 实时查看
tail -f /var/www/heart_sync/logs/app.log

# 查看错误
grep -i error /var/www/heart_sync/logs/app.log
```

### 系统日志
```bash
# 系统日志
/var/log/syslog
/var/log/auth.log
/var/log/kern.log

# systemd 日志
sudo journalctl -f                    # 实时查看
sudo journalctl -u service -f           # 特定服务
sudo journalctl --since "1 hour ago"    # 最近 1 小时
sudo journalctl --since today            # 今天
sudo journalctl -p err                 # 错误级别
```

### 备份管理
```bash
# 备份目录
/var/backups/heart_sync/
/var/backups/postgresql/

# 查看备份
ls -lh /var/backups/heart_sync/
ls -lh /var/backups/postgresql/

# 手动备份
/usr/local/bin/backup_heartsync.sh
/usr/local/bin/backup_postgres.sh

# 恢复备份
tar -xzf /var/backups/heart_sync/code_20240122.tar.gz -C /var/www/
gunzip < /var/backups/postgresql/heart_sync_20240122.sql.gz | \
    sudo -u postgres psql heart_sync
```

---

## 🔧 故障排除

### 端口占用
```bash
# 查看端口占用
sudo lsof -i :5000
sudo ss -tuln | grep 5000

# 查看所有监听端口
sudo ss -tuln
sudo netstat -tuln

# 杀死进程
sudo kill -9 <PID>

# 查看 PID
sudo lsof -i :5000 -t
```

### 连接问题
```bash
# 测试网络
ping -c 4 8.8.8.8
ping -c 4 yourdomain.com

# 测试 DNS
nslookup google.com
dig google.com

# 测试 HTTP
curl -I https://yourdomain.com

# 测试端口
nc -zv yourdomain.com 443
telnet yourdomain.com 443
```

### 服务无法启动
```bash
# 检查服务状态
sudo systemctl status heart_sync

# 查看日志
sudo journalctl -u heart_sync -n 50

# 测试配置
sudo nginx -t

# 手动启动
source venv/bin/activate
python app.py
```

### 性能问题
```bash
# 查看 CPU 使用
top
htop
ps aux | sort -rk 3 | head -20

# 查看内存
free -h
ps aux --sort=-%mem | head -20

# 查看磁盘 I/O
iostat -x 1 5
iotop -o

# 查看网络
nethogs
iftop
```

---

## 📝 常用命令

### 文件操作
```bash
# 复制
cp -r source dest

# 移动/重命名
mv source dest

# 删除
rm -rf directory
rm -f file

# 查找
find /path -name "*.log"
find /path -type f -mtime +7

# 压缩
tar -czf archive.tar.gz directory/
tar -xzf archive.tar.gz

# 权限
chmod 755 file
chmod -R 755 directory
chown user:group file
```

### 进程管理
```bash
# 查看进程
ps aux
ps aux | grep heart_sync

# 查看所有进程
ps -ef

# 杀死进程
kill <PID>
kill -9 <PID>          # 强制杀死
killall python3        # 杀死所有 python3

# 查看资源使用
top
htop
```

### 网络操作
```bash
# 测试连接
ping host
traceroute host

# 查看端口
netstat -tuln
ss -tuln

# 下载
wget http://example.com/file
curl -O http://example.com/file

# SSH 连接
ssh user@host
ssh -p 2222 user@host

# SCP 传输
scp file user@host:/path/
scp user@host:/path/file .
rsync -avz source/ user@host:dest/
```

---

## 🔢 性能优化

### 系统优化
```bash
# 查看 ulimit
ulimit -n
ulimit -u

# 临时修改
ulimit -n 65535

# 永久修改
/etc/security/limits.conf

# 查看 sysctl
sysctl -a | grep tcp
sysctl -a | grep file-max
```

### PostgreSQL 优化
```bash
# 配置文件
/etc/postgresql/14/main/postgresql.conf

# 重要参数
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB

# 查看当前配置
sudo -u postgres psql -c "SHOW ALL;"

# 重启 PostgreSQL
sudo systemctl restart postgresql
```

### Nginx 优化
```bash
# 工作进程数
worker_processes auto;
worker_connections 4096;

# 缓冲区
client_body_buffer_size 128k;
client_max_body_size 10M;

# 启用压缩
gzip on;
gzip_comp_level 6;
```

---

## 📋 检查清单

### 日常检查
- [ ] 检查系统负载
- [ ] 检查磁盘使用
- [ ] 检查内存使用
- [ ] 查看应用日志
- [ ] 查看错误日志
- [ ] 检查服务状态

### 周期检查
- [ ] 系统更新
- [ ] 备份验证
- [ ] 证书有效期检查
- [ ] 安全日志审查
- [ ] 性能指标分析

### 月度检查
- [ ] 全面系统审计
- [ ] 备份测试
- [ ] 性能优化
- [ ] 容量规划
- [ ] 文档更新

---

## 🆘 紧急故障处理

### 应用宕机
```bash
1. 检查服务状态
   sudo systemctl status heart_sync

2. 查看错误日志
   sudo journalctl -u heart_sync -n 100

3. 重启服务
   sudo systemctl restart heart_sync

4. 如果失败，回滚
   sudo bash deploy/rollback.sh --list
   sudo bash deploy/rollback.sh --rollback backup_*
```

### 数据库故障
```bash
1. 检查 PostgreSQL 状态
   sudo systemctl status postgresql

2. 尝试连接
   sudo -u postgres psql

3. 重启服务
   sudo systemctl restart postgresql

4. 如果损坏，恢复备份
   gunzip < backup.sql.gz | psql heart_sync
```

### 安全事件
```bash
1. 查看登录日志
   sudo last
   sudo lastb

2. 检查 Fail2ban
   sudo fail2ban-client status

3. 阻止可疑 IP
   sudo ufw deny from <IP>

4. 更新系统
   sudo apt update && sudo apt upgrade
```

---

## 📞 支持资源

### 文档
- [SERVER_SETUP.md](../SERVER_SETUP.md) - 完整服务器配置指南
- [DEPLOYMENT.md](../DEPLOYMENT.md) - CI/CD 和部署指南
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - 部署完整流程

### 在线资源
- Ubuntu 官方文档: https://ubuntu.com/server/docs
- Nginx 文档: https://nginx.org/en/docs/
- PostgreSQL 文档: https://www.postgresql.org/docs/
- Python 文档: https://docs.python.org/

### 获取帮助
- GitHub Issues
- 社区论坛
- 技术支持

---

**最后更新**: 2024-01-22
