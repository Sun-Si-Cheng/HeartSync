#!/bin/bash

################################################################################
# HeartSync - 增强版自动部署脚本
# 支持多环境部署、回滚机制、详细日志记录
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
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 默认配置
ENVIRONMENT="${1:-development}"
DEPLOY_MODE="${2:-deploy}"  # deploy, rollback, status
DRY_RUN="${3:-false}"

# 项目配置
PROJECT_NAME="heart_sync"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
BACKUP_DIR="/var/backups/${PROJECT_NAME}"
LOG_DIR="${PROJECT_DIR}/logs"
DEPLOY_LOG="${LOG_DIR}/deploy_$(date +%Y%m%d_%H%M%S).log"

# 根据环境加载不同配置
case "$ENVIRONMENT" in
    development|dev)
        ENV_FILE=".env.development"
        SERVICE_NAME="${PROJECT_NAME}-dev"
        PORT=5000
        ;;
    staging|test)
        ENV_FILE=".env.staging"
        SERVICE_NAME="${PROJECT_NAME}-staging"
        PORT=5001
        ;;
    production|prod)
        ENV_FILE=".env.production"
        SERVICE_NAME="${PROJECT_NAME}"
        PORT=80
        ;;
    *)
        log_error "未知环境: $ENVIRONMENT"
        log_info "支持的环境: development, staging, production"
        exit 1
        ;;
esac

# 创建日志目录
mkdir -p "$LOG_DIR"
mkdir -p "$BACKUP_DIR"

# 重定向所有输出到日志文件
exec > >(tee -a "$DEPLOY_LOG")
exec 2>&1

################################################################################
# 辅助函数
################################################################################

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_warning "建议使用root权限运行此脚本"
        log_info "使用命令: sudo bash deploy.sh $ENVIRONMENT $DEPLOY_MODE"
        read -p "是否继续？(y/N): " confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            exit 1
        fi
    fi
}

check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 $1 未找到，请先安装"
        exit 1
    fi
}

check_system_requirements() {
    log_info "检查系统依赖..."
    local required_commands=("python3" "pip3" "nginx" "systemctl" "git")
    for cmd in "${required_commands[@]}"; do
        check_command "$cmd"
    done
    log_success "系统依赖检查通过"
}

create_backup() {
    log_info "创建部署备份..."
    
    if [ ! -d "${PROJECT_DIR}/current" ]; then
        log_warning "当前版本不存在，跳过备份"
        return 0
    fi
    
    local backup_name="backup_$(date +%Y%m%d_%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    mkdir -p "$backup_path"
    
    # 备份代码
    if [ -d "${PROJECT_DIR}/current" ]; then
        cp -r "${PROJECT_DIR}/current" "${backup_path}/"
    fi
    
    # 备份数据库
    if [ -f "${PROJECT_DIR}/current/users.db" ]; then
        cp "${PROJECT_DIR}/current/users.db" "${backup_path}/"
        log_success "数据库已备份到: ${backup_path}/users.db"
    fi
    
    # 备份配置文件
    if [ -f "${PROJECT_DIR}/${ENV_FILE}" ]; then
        cp "${PROJECT_DIR}/${ENV_FILE}" "${backup_path}/"
    fi
    
    # 记录备份信息
    cat > "${backup_path}/backup_info.txt" << EOF
备份时间: $(date)
环境: ${ENVIRONMENT}
备份目录: ${backup_path}
版本信息:
$(cat ${PROJECT_DIR}/current/version.txt 2>/dev/null || echo "N/A")
EOF
    
    log_success "备份创建完成: $backup_name"
    
    # 清理旧备份
    cleanup_old_backups
}

cleanup_old_backups() {
    log_info "清理旧备份（保留最近7天）..."
    find "$BACKUP_DIR" -type d -name "backup_*" -mtime +7 -exec rm -rf {} + 2>/dev/null || true
    log_success "旧备份清理完成"
}

restore_backup() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [ ! -d "$backup_path" ]; then
        log_error "备份不存在: $backup_name"
        exit 1
    fi
    
    log_warning "开始回滚到: $backup_name"
    log_warning "此操作将覆盖当前版本！"
    read -p "确认回滚？(y/N): " confirm
    
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "回滚已取消"
        exit 0
    fi
    
    # 停止服务
    log_info "停止服务..."
    systemctl stop "$SERVICE_NAME" || true
    
    # 备份当前版本
    if [ -d "${PROJECT_DIR}/current" ]; then
        mv "${PROJECT_DIR}/current" "${PROJECT_DIR}/current_failed_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # 恢复备份
    log_info "恢复备份..."
    cp -r "${backup_path}/current" "${PROJECT_DIR}/"
    
    # 恢复数据库
    if [ -f "${backup_path}/users.db" ]; then
        cp "${backup_path}/users.db" "${PROJECT_DIR}/current/"
    fi
    
    # 重启服务
    log_info "重启服务..."
    systemctl start "$SERVICE_NAME"
    systemctl reload nginx
    
    log_success "回滚完成！"
}

list_backups() {
    log_info "可用的备份列表："
    echo ""
    for backup in $(ls -t ${BACKUP_DIR}/backup_* 2>/dev/null); do
        if [ -d "$backup" ]; then
            backup_name=$(basename "$backup")
            backup_time=$(stat -c %y "$backup" | cut -d'.' -f1)
            echo "  - $backup_name ($backup_time)"
            if [ -f "$backup/backup_info.txt" ]; then
                echo "    $(head -n 3 "$backup/backup_info.txt" | tail -n 2 | sed 's/^/    /')"
            fi
        fi
    done
}

health_check() {
    log_info "执行健康检查..."
    
    local max_retries=10
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        if curl -f "http://localhost:${PORT}/health" &> /dev/null; then
            log_success "健康检查通过！"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        log_warning "健康检查失败，重试中... ($retry_count/$max_retries)"
        sleep 3
    done
    
    log_error "健康检查失败！"
    return 1
}

################################################################################
# 部署流程
################################################################################

setup_project() {
    log_info "设置项目目录..."
    mkdir -p "$PROJECT_DIR"
    mkdir -p "${PROJECT_DIR}/current"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BACKUP_DIR"
    log_success "项目目录已创建"
}

install_dependencies() {
    log_info "安装系统依赖..."
    apt-get update -qq
    apt-get install -y -qq \
        python3 \
        python3-pip \
        python3-venv \
        nginx \
        git \
        sqlite3 \
        supervisor \
        certbot \
        python3-certbot-nginx &> /dev/null
    log_success "系统依赖已安装"
}

setup_python_env() {
    log_info "设置Python虚拟环境..."
    
    if [ ! -d "${PROJECT_DIR}/venv" ]; then
        python3 -m venv "${PROJECT_DIR}/venv"
        log_success "虚拟环境已创建"
    else
        log_success "虚拟环境已存在"
    fi
    
    source "${PROJECT_DIR}/venv/bin/activate"
    pip install --upgrade pip -qq
    log_success "pip已升级"
}

install_python_packages() {
    log_info "安装Python依赖包..."
    source "${PROJECT_DIR}/venv/bin/activate"
    
    if [ -f "${PROJECT_DIR}/current/requirements.txt" ]; then
        pip install -r "${PROJECT_DIR}/current/requirements.txt" -qq
        log_success "Python依赖包已安装"
    else
        log_warning "requirements.txt 未找到"
    fi
}

configure_app() {
    log_info "配置应用..."
    
    # 复制环境配置文件
    if [ -f "${PROJECT_DIR}/${ENV_FILE}" ]; then
        cp "${PROJECT_DIR}/${ENV_FILE}" "${PROJECT_DIR}/current/.env"
        log_success "环境配置已加载"
    else
        log_warning "环境配置文件未找到: ${ENV_FILE}"
    fi
    
    # 配置文件权限
    chown -R www-data:www-data "${PROJECT_DIR}/current"
    chmod -R 755 "${PROJECT_DIR}/current"
    log_success "文件权限已设置"
}

init_database() {
    log_info "初始化数据库..."
    source "${PROJECT_DIR}/venv/bin/activate"
    
    cd "${PROJECT_DIR}/current"
    export FLASK_APP=app.py
    export FLASK_ENV=production
    
    python -c "from app import app, db, init_db; app.app_context().push(); init_db()" &> /dev/null
    log_success "数据库已初始化"
}

configure_systemd() {
    log_info "配置systemd服务..."
    
    # 创建systemd服务文件
    cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=HeartSync Application (${ENVIRONMENT})
After=network.target

[Service]
Type=notify
User=www-data
Group=www-data
WorkingDirectory=${PROJECT_DIR}/current
Environment="PATH=${PROJECT_DIR}/venv/bin"
ExecStart=${PROJECT_DIR}/venv/bin/gunicorn -w 4 -b 127.0.0.1:${PORT} --timeout 120 --access-logfile - --error-logfile - app:app
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    systemctl enable "$SERVICE_NAME"
    log_success "systemd服务已配置"
}

configure_nginx() {
    log_info "配置Nginx..."
    
    # 创建Nginx配置
    cat > "/etc/nginx/sites-available/${SERVICE_NAME}" << EOF
server {
    listen 80;
    server_name _;

    client_max_body_size 10M;

    location / {
        proxy_pass http://127.0.0.1:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;

        # WebSocket支持
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location /static {
        alias ${PROJECT_DIR}/current/static;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    ln -sf "/etc/nginx/sites-available/${SERVICE_NAME}" "/etc/nginx/sites-enabled/${SERVICE_NAME}"
    
    nginx -t
    systemctl reload nginx
    log_success "Nginx已配置"
}

deploy_new_version() {
    log_info "部署新版本..."
    
    # 如果是从当前目录部署
    if [ -d "./" ] && [ -f "./app.py" ]; then
        log_info "从当前目录部署..."
        
        # 创建临时目录
        local temp_dir="${PROJECT_DIR}/temp_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$temp_dir"
        
        # 复制文件
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
                  . "$temp_dir/"
        
        # 创建版本信息
        cat > "$temp_dir/version.txt" << EOF
VERSION=$(date +%Y.%m.%d)-${RANDOM}
BUILD_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
DEPLOYMENT_TIME=$(date)
ENVIRONMENT=${ENVIRONMENT}
DEPLOYED_BY=$(whoami)
EOF
        
        # 停止服务
        systemctl stop "$SERVICE_NAME" || true
        
        # 切换版本
        mv "${PROJECT_DIR}/current" "${PROJECT_DIR}/current_old" 2>/dev/null || true
        mv "$temp_dir" "${PROJECT_DIR}/current"
        rm -rf "${PROJECT_DIR}/current_old" 2>/dev/null || true
        
        log_success "文件已部署"
        
    else
        log_error "未找到有效的部署源"
        exit 1
    fi
}

restart_services() {
    log_info "重启服务..."
    
    systemctl restart "$SERVICE_NAME"
    systemctl reload nginx
    
    log_success "服务已重启"
}

################################################################################
# 主流程
################################################################################

main() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  HeartSync - 自动部署系统${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    log_info "环境: $ENVIRONMENT"
    log_info "模式: $DEPLOY_MODE"
    log_info "日志: $DEPLOY_LOG"
    echo ""
    
    check_root
    check_system_requirements
    
    case "$DEPLOY_MODE" in
        deploy)
            log_info "开始部署流程..."
            
            # 创建备份
            create_backup
            
            # 部署新版本
            if [ "$DRY_RUN" != "true" ]; then
                deploy_new_version
                setup_python_env
                install_python_packages
                configure_app
                init_database
                configure_systemd
                configure_nginx
                restart_services
                health_check
                
                log_success "部署完成！"
                echo ""
                log_info "服务状态: systemctl status $SERVICE_NAME"
                log_info "访问地址: http://localhost:${PORT}"
                log_info "日志查看: journalctl -u $SERVICE_NAME -f"
            else
                log_warning "模拟部署模式，未执行实际操作"
            fi
            ;;
            
        rollback)
            if [ -z "$3" ]; then
                log_error "请指定备份名称"
                list_backups
                exit 1
            fi
            restore_backup "$3"
            ;;
            
        backup)
            create_backup
            ;;
            
        status)
            log_info "系统状态："
            echo ""
            systemctl status "$SERVICE_NAME" --no-pager
            echo ""
            systemctl status nginx --no-pager
            echo ""
            ;;
            
        list)
            list_backups
            ;;
            
        *)
            log_error "未知模式: $DEPLOY_MODE"
            log_info "可用模式: deploy, rollback, backup, status, list"
            exit 1
            ;;
    esac
    
    echo ""
    log_success "操作完成！日志已保存到: $DEPLOY_LOG"
}

# 执行主函数
main
