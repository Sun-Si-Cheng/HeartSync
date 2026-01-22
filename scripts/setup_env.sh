#!/bin/bash

################################################################################
# HeartSync - 环境初始化脚本
# 用于快速设置开发、测试和生产环境
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

# 生成随机密钥
generate_secret() {
    python3 -c "import secrets; print(secrets.token_hex(32))"
}

# 创建环境配置文件
create_env_file() {
    local env_name="$1"
    local env_file=".env.${env_name}"
    
    log_info "创建 ${env_file}..."
    
    if [ -f "$env_file" ]; then
        log_warning "${env_file} 已存在，跳过创建"
        return 0
    fi
    
    cat > "$env_file" << EOF
# ${env_name} 环境配置
# 创建时间: $(date)

# 应用环境
APP_ENV=${env_name}

# Flask配置
FLASK_APP=app.py
FLASK_ENV=${env_name}
SECRET_KEY=$(generate_secret)
DEBUG=$([ "$env_name" = "development" ] && echo "True" || echo "False")

# 数据库配置
# SQLite (开发环境)
DATABASE_URL=sqlite:///users.db

# PostgreSQL (生产环境推荐)
# DATABASE_URL=postgresql://username:password@localhost:5432/heart_sync

# 服务器配置
HOST=0.0.0.0
PORT=5000

# 日志配置
LOG_LEVEL=$([ "$env_name" = "development" ] && echo "DEBUG" || echo "INFO")
LOG_FILE=logs/app.log

# 部署配置
DEPLOY_USER=deploy
DEPLOY_HOST=your-server-ip
DEPLOY_PATH=/var/www/heart_sync
DEPLOY_KEY=~/.ssh/id_rsa

# Git配置
GIT_REPO=your-git-repo-url
GIT_BRANCH=$([ "$env_name" = "development" ] && echo "develop" || echo "main")

# 备份配置
BACKUP_ENABLED=True
BACKUP_RETENTION_DAYS=7
BACKUP_PATH=/var/www/heart_sync/backup

# 健康检查
HEALTH_CHECK_ENABLED=True
HEALTH_CHECK_INTERVAL=60
HEALTH_CHECK_TIMEOUT=10
HEALTH_CHECK_URL=http://localhost:5000/health

# 回滚配置
ROLLBACK_ENABLED=True
ROLLBACK_MAX_VERSIONS=5

# CORS配置（生产环境需要设置具体域名）
CORS_ALLOWED_ORIGINS=$([ "$env_name" = "production" ] && echo "https://yourdomain.com" || echo "*")

# Session配置
SESSION_COOKIE_SECURE=$([ "$env_name" = "production" ] && echo "True" || echo "False")
EOF
    
    log_success "${env_file} 已创建"
}

# 创建所有环境配置
create_all_envs() {
    log_info "创建所有环境配置..."
    
    create_env_file "development"
    create_env_file "staging"
    create_env_file "production"
    
    log_success "所有环境配置已创建"
}

# 初始化项目结构
init_project_structure() {
    log_info "初始化项目结构..."
    
    mkdir -p logs
    mkdir -p backup
    mkdir -p deploy/package
    mkdir -p data
    
    log_success "项目结构已初始化"
}

# 安装依赖
install_dependencies() {
    log_info "安装 Python 依赖..."
    
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        log_success "虚拟环境已创建"
    fi
    
    source venv/bin/activate
    pip install --upgrade pip -q
    pip install -r requirements.txt -q
    
    if [ -f "requirements-test.txt" ]; then
        pip install -r requirements-test.txt -q
        log_success "测试依赖已安装"
    fi
    
    log_success "依赖安装完成"
}

# 初始化数据库
init_database() {
    log_info "初始化数据库..."
    
    source venv/bin/activate
    export FLASK_APP=app.py
    python -c "from app import app, db, init_db; app.app_context().push(); init_db()"
    
    log_success "数据库已初始化"
}

# 运行测试
run_tests() {
    log_info "运行测试..."
    
    source venv/bin/activate
    pytest tests/ -v --cov=. --cov-report=term-missing
    
    log_success "测试完成"
}

# 显示帮助信息
show_help() {
    cat << EOF
HeartSync - 环境初始化脚本

用法: $0 [选项]

选项:
  --all               完整初始化（所有步骤）
  --envs              创建环境配置文件
  --deps              安装依赖
  --db                初始化数据库
  --test              运行测试
  --dev               快速设置开发环境
  --help              显示此帮助信息

示例:
  $0 --all            # 完整初始化
  $0 --dev            # 快速设置开发环境
  $0 --envs           # 仅创建环境配置文件
  $0 --deps --db      # 安装依赖并初始化数据库
EOF
}

# 主函数
main() {
    case "$1" in
        --all)
            create_all_envs
            init_project_structure
            install_dependencies
            init_database
            log_success "完整初始化完成！"
            ;;
        --envs)
            create_all_envs
            ;;
        --deps)
            install_dependencies
            ;;
        --db)
            init_database
            ;;
        --test)
            run_tests
            ;;
        --dev)
            create_env_file "development"
            init_project_structure
            install_dependencies
            init_database
            log_success "开发环境设置完成！"
            log_info "运行 'source venv/bin/activate && python app.py' 启动应用"
            ;;
        --help|"")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
