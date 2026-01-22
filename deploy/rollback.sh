#!/bin/bash

################################################################################
# HeartSync - 回滚脚本
# 用于快速回滚到之前的版本
################################################################################

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 项目配置
PROJECT_NAME="heart_sync"
BACKUP_DIR="/var/backups/${PROJECT_NAME}"

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

# 显示使用说明
show_usage() {
    echo "HeartSync 回滚脚本"
    echo ""
    echo "用法: $0 [选项] [备份名称]"
    echo ""
    echo "选项:"
    echo "  -l, --list              列出所有可用备份"
    echo "  -r, --rollback NAME     回滚到指定备份"
    echo "  -c, --check             检查当前版本状态"
    echo "  -h, --help              显示帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --list"
    echo "  $0 --rollback backup_20240122_120000"
    echo "  $0 -r backup_20240122_120000"
}

# 列出所有备份
list_backups() {
    log_info "可用的备份列表："
    echo ""
    
    local backups=($(ls -t ${BACKUP_DIR}/backup_* 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        log_warning "没有找到备份"
        return 1
    fi
    
    local index=1
    for backup in "${backups[@]}"; do
        if [ -d "$backup" ]; then
            backup_name=$(basename "$backup")
            backup_time=$(stat -c %y "$backup" 2>/dev/null | cut -d'.' -f1)
            backup_size=$(du -sh "$backup" 2>/dev/null | cut -f1)
            
            echo "  [${index}] ${backup_name}"
            echo "      时间: ${backup_time}"
            echo "      大小: ${backup_size}"
            
            if [ -f "$backup/backup_info.txt" ]; then
                echo "      详情:"
                grep -E "环境:|版本信息:" "$backup/backup_info.txt" 2>/dev/null | sed 's/^/        /'
            fi
            echo ""
            index=$((index + 1))
        fi
    done
    
    return 0
}

# 检查当前版本状态
check_current_status() {
    log_info "当前版本状态："
    echo ""
    
    local current_dir="/var/www/${PROJECT_NAME}/current"
    
    if [ -d "$current_dir" ]; then
        echo "  目录存在: 是"
        
        if [ -f "$current_dir/version.txt" ]; then
            echo ""
            echo "  版本信息:"
            cat "$current_dir/version.txt" | sed 's/^/    /'
        fi
        
        if [ -f "$current_dir/users.db" ]; then
            echo ""
            echo "  数据库: 存在"
            local db_size=$(du -h "$current_dir/users.db" | cut -f1)
            echo "    大小: $db_size"
        fi
    else
        log_warning "当前版本目录不存在"
    fi
    
    echo ""
    log_info "服务状态："
    systemctl status "${PROJECT_NAME}" --no-pager -l | head -n 10
}

# 验证备份
verify_backup() {
    local backup_path="$1"
    
    if [ ! -d "$backup_path" ]; then
        log_error "备份不存在: $backup_path"
        return 1
    fi
    
    if [ ! -d "$backup_path/current" ]; then
        log_error "备份不完整: 缺少current目录"
        return 1
    fi
    
    if [ ! -f "$backup_path/current/app.py" ]; then
        log_error "备份不完整: 缺少app.py"
        return 1
    fi
    
    return 0
}

# 执行回滚
perform_rollback() {
    local backup_name="$1"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    # 验证备份
    if ! verify_backup "$backup_path"; then
        exit 1
    fi
    
    log_info "准备回滚到: $backup_name"
    log_warning "此操作将覆盖当前版本！"
    echo ""
    
    # 显示备份信息
    if [ -f "$backup_path/backup_info.txt" ]; then
        echo "备份信息:"
        cat "$backup_path/backup_info.txt" | sed 's/^/  /'
        echo ""
    fi
    
    read -p "确认回滚？输入 'yes' 继续: " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "回滚已取消"
        exit 0
    fi
    
    echo ""
    log_info "开始回滚..."
    
    # 停止服务
    log_info "停止服务..."
    systemctl stop "${PROJECT_NAME}" || true
    sleep 2
    
    # 备份当前版本（如果存在）
    local current_dir="/var/www/${PROJECT_NAME}/current"
    if [ -d "$current_dir" ]; then
        local failed_backup="${current_dir}_failed_$(date +%Y%m%d_%H%M%S)"
        mv "$current_dir" "$failed_backup"
        log_info "当前版本已备份到: $failed_backup"
    fi
    
    # 恢复备份
    log_info "恢复备份..."
    cp -r "$backup_path/current" "/var/www/${PROJECT_NAME}/"
    
    # 恢复数据库
    if [ -f "$backup_path/users.db" ]; then
        cp "$backup_path/users.db" "/var/www/${PROJECT_NAME}/current/"
        log_success "数据库已恢复"
    fi
    
    # 恢复配置文件
    if [ -f "$backup_path/.env.development" ]; then
        cp "$backup_path/.env.development" "/var/www/${PROJECT_NAME}/"
    fi
    
    # 设置权限
    log_info "设置文件权限..."
    chown -R www-data:www-data "/var/www/${PROJECT_NAME}/current"
    chmod -R 755 "/var/www/${PROJECT_NAME}/current"
    
    # 重启服务
    log_info "重启服务..."
    systemctl start "${PROJECT_NAME}"
    sleep 3
    
    # 检查服务状态
    if systemctl is-active --quiet "${PROJECT_NAME}"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        systemctl status "${PROJECT_NAME}" --no-pager
        exit 1
    fi
    
    # 健康检查
    log_info "执行健康检查..."
    sleep 2
    if curl -f "http://localhost:5000/health" &> /dev/null; then
        log_success "健康检查通过"
    else
        log_warning "健康检查失败，请检查日志"
    fi
    
    echo ""
    log_success "回滚完成！"
    echo ""
    log_info "查看服务状态: systemctl status ${PROJECT_NAME}"
    log_info "查看日志: journalctl -u ${PROJECT_NAME} -f"
}

# 创建快速回滚备份（用于回滚之前的版本）
create_quick_rollback() {
    local current_dir="/var/www/${PROJECT_NAME}/current"
    local backup_name="quick_rollback_$(date +%Y%m%d_%H%M%S)"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    if [ ! -d "$current_dir" ]; then
        log_error "当前版本目录不存在"
        exit 1
    fi
    
    log_info "创建快速回滚备份: $backup_name"
    
    mkdir -p "$backup_path"
    cp -r "$current_dir" "$backup_path/"
    
    if [ -f "$current_dir/users.db" ]; then
        cp "$current_dir/users.db" "$backup_path/"
    fi
    
    # 创建备份信息
    cat > "$backup_path/backup_info.txt" << EOF
备份时间: $(date)
备份类型: 快速回滚备份
环境: $(grep '^APP_ENV=' $current_dir/.env 2>/dev/null | cut -d'=' -f2 || echo 'unknown')
说明: 在新版本部署前自动创建的备份
EOF
    
    log_success "快速回滚备份已创建: $backup_name"
    return 0
}

# 主函数
main() {
    # 检查是否为root用户
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        echo "使用命令: sudo bash $0 $*"
        exit 1
    fi
    
    # 没有参数时显示帮助
    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi
    
    # 解析参数
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -l|--list)
            list_backups
            exit 0
            ;;
        -c|--check)
            check_current_status
            exit 0
            ;;
        -r|--rollback)
            if [ -z "$2" ]; then
                log_error "请指定备份名称"
                echo ""
                list_backups
                exit 1
            fi
            perform_rollback "$2"
            exit 0
            ;;
        --create-quick)
            create_quick_rollback
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
