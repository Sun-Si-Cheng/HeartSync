#!/bin/bash

################################################################################
# Ubuntu 22.04 服务器初始化脚本
# 用于快速配置生产环境服务器
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        echo "使用命令: sudo bash $0"
        exit 1
    fi
}

# 显示欢迎信息
show_banner() {
    echo -e "${GREEN}"
    echo "========================================"
    echo "  Ubuntu 22.04 服务器初始化"
    echo "========================================"
    echo -e "${NC}"
}

# 更新系统
update_system() {
    log_info "更新系统..."
    apt update -qq
    apt upgrade -y -qq
    apt dist-upgrade -y -qq
    apt autoremove -y -qq
    apt autoclean -y -qq
    log_success "系统已更新"
}

# 设置主机名
set_hostname() {
    read -p "请输入主机名（默认: heartsync-server）: " HOSTNAME
    HOSTNAME=${HOSTNAME:-heartsync-server}
    hostnamectl set-hostname "$HOSTNAME"
    
    # 更新 hosts 文件
    IP=$(hostname -I | awk '{print $1}')
    sed -i.bak "s/127.0.1.1.*/127.0.1.1   $HOSTNAME/" /etc/hosts
    
    log_success "主机名已设置为: $HOSTNAME"
}

# 设置时区
set_timezone() {
    read -p "请输入时区（默认: Asia/Shanghai）: " TZ
    TZ=${TZ:-Asia/Shanghai}
    timedatectl set-timezone "$TZ"
    log_success "时区已设置为: $TZ"
}

# 安装基础工具
install_basic_tools() {
    log_info "安装基础工具..."
    apt install -y curl wget git vim htop tree zip unzip rsync jq \
        tmux screen net-tools lsof iotop strace tcpdump ncdu nc telnet \
        software-properties-common apt-transport-https ca-certificates gnupg \
        lsb-release build-essential -qq
    log_success "基础工具已安装"
}

# 配置 NTP
configure_ntp() {
    log_info "配置 NTP 时间同步..."
    apt install -y ntp -qq
    
    # 配置中国 NTP 服务器
    cat > /etc/ntp.conf << EOF
server ntp.aliyun.com iburst
server cn.ntp.org.cn iburst
restrict default nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1
driftfile /var/lib/ntp/drift
EOF
    
    systemctl enable ntp
    systemctl start ntp
    log_success "NTP 已配置"
}

# 创建部署用户
create_deploy_user() {
    log_info "创建部署用户..."
    
    if id "deploy" &>/dev/null; then
        log_warning "deploy 用户已存在"
    else
        useradd -m -s /bin/bash deploy
        usermod -aG sudo deploy
        
        # 配置 sudo 免密码
        echo "deploy ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/deploy
        chmod 0440 /etc/sudoers.d/deploy
        
        # 创建 SSH 密钥
        su - deploy -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh"
        su - deploy -c "ssh-keygen -t ed25519 -b 4096 -f ~/.ssh/id_ed25519 -N ''"
        su - deploy -c "cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
        
        log_success "deploy 用户已创建"
        echo "公钥: $(su - deploy -c 'cat ~/.ssh/id_ed25519.pub')"
    fi
}

# 配置 SSH
configure_ssh() {
    log_info "配置 SSH..."
    
    read -p "请输入 SSH 端口（默认: 2222）: " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    
    # 备份原配置
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # 配置 SSH
    cat > /etc/ssh/sshd_config << EOF
Port $SSH_PORT
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
AllowAgentForwarding no
GatewayPorts no
UseDNS no
EOF
    
    # 测试配置
    sshd -t
    
    systemctl restart sshd
    log_success "SSH 已配置（端口: $SSH_PORT）"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."
    
    apt install -y ufw -qq
    
    ufw default deny incoming
    ufw default allow outgoing
    
    read -p "请输入 SSH 端口（默认: 2222）: " SSH_PORT
    SSH_PORT=${SSH_PORT:-2222}
    
    ufw allow "$SSH_PORT/tcp" comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    ufw --force enable
    log_success "防火墙已配置"
    ufw status
}

# 配置 Fail2ban
configure_fail2ban() {
    log_info "配置 Fail2ban..."
    
    apt install -y fail2ban -qq
    
    cat > /etc/fail2ban/jail.local << EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
ignoreip = 127.0.0.1/8

[sshd]
enabled = true
port = 2222
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
EOF
    
    systemctl enable fail2ban
    systemctl start fail2ban
    log_success "Fail2ban 已配置"
}

# 配置系统安全参数
configure_sysctl() {
    log_info "配置系统安全参数..."
    
    cat > /etc/sysctl.d/99-security.conf << EOF
# Network Security
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# SYN Attack Protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# TCP Optimization
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_probes = 3
net.ipv4.tcp_keepalive_intvl = 15
net.ipv4.tcp_fin_timeout = 30

# File Descriptors
fs.file-max = 65535
EOF
    
    sysctl -p /etc/sysctl.d/99-security.conf
    log_success "系统安全参数已配置"
}

# 配置文件描述符限制
configure_limits() {
    log_info "配置文件描述符限制..."
    
    cat > /etc/security/limits.d/99-heartsync.conf << EOF
* soft nofile 65535
* hard nofile 65535
* soft nproc 65535
* hard nproc 65535
EOF
    
    cat > /etc/systemd/system.conf.d/limits.conf << EOF
[Manager]
DefaultLimitNOFILE=65535
DefaultLimitNPROC=65535
EOF
    
    systemctl daemon-reload
    log_success "文件描述符限制已配置"
}

# 安装 Python
install_python() {
    log_info "安装 Python 环境..."
    
    apt install -y python3 python3-pip python3-venv python3-dev \
        libssl-dev libffi-dev python3-setuptools -qq
    
    pip3 install --upgrade pip setuptools wheel -qq
    
    log_success "Python 已安装"
    python3 --version
    pip3 --version
}

# 安装 PostgreSQL
install_postgresql() {
    log_info "安装 PostgreSQL..."
    
    apt install -y postgresql postgresql-contrib -qq
    
    systemctl enable postgresql
    systemctl start postgresql
    
    # 创建数据库和用户
    read -p "请输入数据库密码（默认: heartsync123）: " DB_PASSWORD
    DB_PASSWORD=${DB_PASSWORD:-heartsync123}
    
    sudo -u postgres psql << EOF
CREATE USER heart_sync WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE heart_sync OWNER heart_sync;
GRANT ALL PRIVILEGES ON DATABASE heart_sync TO heart_sync;
EOF
    
    log_success "PostgreSQL 已安装"
    echo "数据库: heart_sync"
    echo "用户: heart_sync"
    echo "密码: $DB_PASSWORD"
}

# 安装 Nginx
install_nginx() {
    log_info "安装 Nginx..."
    
    apt install -y nginx -qq
    
    systemctl enable nginx
    systemctl start nginx
    
    log_success "Nginx 已安装"
}

# 配置项目目录
setup_project_dirs() {
    log_info "配置项目目录..."
    
    mkdir -p /var/www/heart_sync/{logs,backup,static,templates,data}
    mkdir -p /var/backups/{heart_sync,postgresql}
    
    chown -R deploy:deploy /var/www/heart_sync
    chown -R www-data:www-data /var/www/heart_sync/data
    
    log_success "项目目录已创建"
}

# 配置日志轮转
configure_logrotate() {
    log_info "配置日志轮转..."
    
    cat > /etc/logrotate.d/heart_sync << EOF
/var/www/heart_sync/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 0644 deploy deploy
}
EOF
    
    log_success "日志轮转已配置"
}

# 安装监控工具
install_monitoring() {
    log_info "安装监控工具..."
    
    apt install -y htop iotop nethogs sysstat -qq
    
    systemctl enable sysstat
    systemctl start sysstat
    
    log_success "监控工具已安装"
}

# 配置自动备份
setup_backup() {
    log_info "配置自动备份..."
    
    # PostgreSQL 备份脚本
    cat > /usr/local/bin/backup_postgres.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +%Y%m%d_%H%M%S)
DB_NAME="heart_sync"
DB_USER="heart_sync"
mkdir -p "$BACKUP_DIR"
su - postgres -c "pg_dump -U $DB_USER $DB_NAME" | gzip > "$BACKUP_DIR/${DB_NAME}_${DATE}.sql.gz"
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime +7 -delete
echo "Backup completed: ${DB_NAME}_${DATE}.sql.gz"
EOF
    
    chmod +x /usr/local/bin/backup_postgres.sh
    
    # 应用备份脚本
    cat > /usr/local/bin/backup_heartsync.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/var/backups/heart_sync"
PROJECT_DIR="/var/www/heart_sync"
DATE=$(date +%Y%m%d_%H%M%S)
mkdir -p "$BACKUP_DIR"
cd /var/www
tar -czf "$BACKUP_DIR/code_$DATE.tar.gz" heart_sync --exclude='venv' --exclude='*.pyc' --exclude='__pycache__'
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +7 -delete
echo "Backup completed: code_$DATE.tar.gz"
EOF
    
    chmod +x /usr/local/bin/backup_heartsync.sh
    
    # 添加到 cron
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup_postgres.sh >> /var/log/postgres_backup.log 2>&1") | crontab -
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/backup_heartsync.sh >> /var/log/heart_sync_backup.log 2>&1") | crontab -
    
    log_success "自动备份已配置"
}

# 配置系统检查脚本
setup_health_check() {
    log_info "配置健康检查脚本..."
    
    cat > /usr/local/bin/check_system.sh << 'EOF'
#!/bin/bash
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    logger -p local0.warning "Disk usage: ${DISK_USAGE}%"
fi
if ! systemctl is-active --quiet nginx; then
    logger -p local0.warning "Nginx is not running"
fi
EOF
    
    chmod +x /usr/local/bin/check_system.sh
    (crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/check_system.sh") | crontab -
    
    log_success "健康检查已配置"
}

# 显示完成信息
show_completion() {
    echo ""
    echo -e "${GREEN}========================================"
    echo -e "  服务器初始化完成！"
    echo -e "========================================"
    echo -e "${NC}"
    echo ""
    echo "重要信息："
    echo "  部署用户: deploy"
    echo "  SSH 端口: ${SSH_PORT:-2222}"
    echo "  主机名: $(hostname)"
    echo "  时区: $(timedatectl | grep 'Time zone' | awk '{print $3}')"
    echo ""
    echo "SSH 公钥："
    su - deploy -c 'cat ~/.ssh/id_ed25519.pub'
    echo ""
    echo "数据库信息："
    echo "  数据库: heart_sync"
    echo "  用户: heart_sync"
    echo "  密码: ${DB_PASSWORD:-heartsync123}"
    echo ""
    echo "下一步："
    echo "  1. 将 SSH 公钥添加到本地电脑"
    echo "  2. 使用 'ssh -p ${SSH_PORT:-2222} deploy@$(hostname -I | awk '{print $1}')' 连接服务器"
    echo "  3. 部署 HeartSync 应用"
    echo ""
    echo "查看日志："
    echo "  systemctl status nginx"
    echo "  systemctl status postgresql"
    echo "  journalctl -u ntp -f"
    echo ""
}

# 主函数
main() {
    show_banner
    
    check_root
    
    echo "开始服务器初始化..."
    echo ""
    
    # 询问要执行的步骤
    read -p "是否执行完整初始化？(y/n，默认: y): " FULL_INIT
    FULL_INIT=${FULL_INIT:-y}
    
    if [ "$FULL_INIT" = "y" ] || [ "$FULL_INIT" = "Y" ]; then
        update_system
        set_hostname
        set_timezone
        install_basic_tools
        configure_ntp
        create_deploy_user
        configure_ssh
        configure_firewall
        configure_fail2ban
        configure_sysctl
        configure_limits
        install_python
        install_postgresql
        install_nginx
        setup_project_dirs
        configure_logrotate
        install_monitoring
        setup_backup
        setup_health_check
    else
        echo ""
        echo "选择要执行的步骤："
        echo "  1) 更新系统"
        echo "  2) 设置主机名"
        echo "  3) 安装基础工具"
        echo "  4) 配置 SSH"
        echo "  5) 配置防火墙"
        echo "  6) 配置 Fail2ban"
        echo "  7) 安装 Python"
        echo "  8) 安装 PostgreSQL"
        echo "  9) 安装 Nginx"
        echo " 10) 配置项目目录"
        echo "  11) 配置备份"
        echo "  12) 全部"
        echo ""
        read -p "请选择 (1-12): " CHOICE
        
        case $CHOICE in
            1) update_system ;;
            2) set_hostname ;;
            3) install_basic_tools ;;
            4) configure_ssh ;;
            5) configure_firewall ;;
            6) configure_fail2ban ;;
            7) install_python ;;
            8) install_postgresql ;;
            9) install_nginx ;;
            10) setup_project_dirs ;;
            11) setup_backup ;;
            12)
                update_system
                set_hostname
                install_basic_tools
                configure_ssh
                configure_firewall
                configure_fail2ban
                install_python
                install_postgresql
                install_nginx
                setup_project_dirs
                setup_backup
                ;;
            *)
                log_error "无效选择"
                exit 1
                ;;
        esac
    fi
    
    show_completion
}

# 执行主函数
main "$@"
