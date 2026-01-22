#!/bin/bash

################################################################################
# HeartSync 应用部署脚本
# 用于在配置好的服务器上部署应用
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# 部署应用
deploy_app() {
    local PROJECT_DIR="/var/www/heart_sync"
    local VENV_DIR="$PROJECT_DIR/venv"
    local SERVICE_NAME="heart_sync"
    
    log_info "开始部署 HeartSync 应用..."
    
    # 检查部署源
    if [ ! -d "./" ] || [ ! -f "app.py" ]; then
        log_error "未找到应用源代码"
        log_info "请在 HeartSync 项目根目录下运行此脚本"
        exit 1
    fi
    
    # 备份当前版本
    if [ -d "$PROJECT_DIR/current" ]; then
        log_info "备份当前版本..."
        BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
        cp -r "$PROJECT_DIR/current" "$PROJECT_DIR/backup/$BACKUP_NAME"
        log_success "备份完成: $BACKUP_NAME"
    fi
    
    # 部署新版本
    log_info "部署新版本..."
    TEMP_DIR="$PROJECT_DIR/temp_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$TEMP_DIR"
    
    # 复制应用文件
    rsync -av --exclude='.git' \
              --exclude='__pycache__' \
              --exclude='*.pyc' \
              --exclude='.pytest_cache' \
              --exclude='htmlcov' \
              --exclude='.coverage' \
              --exclude='venv' \
              --exclude='.env.*' \
              --exclude='logs' \
              --exclude='backup' \
              . "$TEMP_DIR/"
    
    # 创建版本信息
    cat > "$TEMP_DIR/version.txt" << EOF
VERSION=$(date +%Y.%m.%d)-${RANDOM}
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DEPLOY_TIME=$(date)
ENVIRONMENT=production
EOF
    
    # 切换版本
    if [ -d "$PROJECT_DIR/current" ]; then
        mv "$PROJECT_DIR/current" "$PROJECT_DIR/current_old" || true
    fi
    mv "$TEMP_DIR" "$PROJECT_DIR/current"
    rm -rf "$PROJECT_DIR/current_old" 2>/dev/null || true
    
    log_success "文件已部署"
    
    # 配置环境
    log_info "配置环境..."
    if [ -f "$PROJECT_DIR/.env.production" ]; then
        cp "$PROJECT_DIR/.env.production" "$PROJECT_DIR/current/.env"
    else
        log_warning "未找到 .env.production，使用默认配置"
    fi
    
    # 创建虚拟环境
    if [ ! -d "$VENV_DIR" ]; then
        log_info "创建 Python 虚拟环境..."
        python3 -m venv "$VENV_DIR"
    fi
    
    # 安装依赖
    log_info "安装 Python 依赖..."
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip -qq
    pip install gunicorn -qq
    pip install -r "$PROJECT_DIR/current/requirements.txt" -qq
    deactivate
    
    # 设置权限
    log_info "设置文件权限..."
    chown -R www-data:www-data "$PROJECT_DIR/current"
    chmod -R 755 "$PROJECT_DIR/current"
    
    # 初始化数据库
    log_info "初始化数据库..."
    source "$VENV_DIR/bin/activate"
    cd "$PROJECT_DIR/current"
    export FLASK_APP=app.py
    python -c "from app import app, db, init_db; app.app_context().push(); init_db()" 2>&1 || log_warning "数据库初始化失败"
    deactivate
    
    # 配置 systemd 服务
    log_info "配置 systemd 服务..."
    cat > "/etc/systemd/system/$SERVICE_NAME.service" << EOF
[Unit]
Description=HeartSync Application
After=network.target postgresql.service nginx.service

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=$PROJECT_DIR/current
Environment="PATH=$VENV_DIR/bin"
ExecStart=$VENV_DIR/bin/gunicorn \
    -w 4 \
    -b 127.0.0.1:5000 \
    --timeout 120 \
    --access-logfile - \
    --error-logfile - \
    --log-level info \
    app:app
ExecReload=/bin/kill -s HUP \$MAINPID
KillMode=mixed
TimeoutStopSec=5
PrivateTmp=true
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    
    # 启动服务
    log_info "启动服务..."
    systemctl restart "$SERVICE_NAME"
    systemctl reload nginx
    
    # 健康检查
    log_info "执行健康检查..."
    sleep 5
    for i in {1..10}; do
        if curl -f "http://localhost:5000/health" &> /dev/null; then
            log_success "健康检查通过"
            break
        fi
        if [ $i -eq 10 ]; then
            log_error "健康检查失败"
            log_info "检查日志: journalctl -u $SERVICE_NAME -n 50"
            exit 1
        fi
        sleep 2
    done
    
    log_success "应用部署完成！"
    echo ""
    log_info "服务状态: systemctl status $SERVICE_NAME"
    log_info "查看日志: journalctl -u $SERVICE_NAME -f"
    log_info "访问地址: http://$(hostname -I | awk '{print $1}')"
}

# 主函数
main() {
    echo -e "${GREEN}"
    echo "========================================"
    echo "  HeartSync 应用部署"
    echo "========================================"
    echo -e "${NC}"
    echo ""
    
    check_root
    deploy_app
}

main "$@"
