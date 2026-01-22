#!/bin/bash

################################################################################
# HeartSync - 健康检查脚本
# 定期检查应用健康状态并发送告警
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
PROJECT_NAME="heart_sync"
LOG_DIR="/var/www/${PROJECT_NAME}/logs"
HEALTH_LOG="${LOG_DIR}/health_check_$(date +%Y%m%d).log"
ALERT_LOG="${LOG_DIR}/alerts.log"

# 检查URL
HEALTH_URL="http://localhost:5000/health"

# 超时设置（秒）
TIMEOUT=10

# 告警阈值（连续失败次数）
ALERT_THRESHOLD=3

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$HEALTH_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# 创建日志目录
mkdir -p "$LOG_DIR"

# 连续失败计数器
FAILED_COUNT=0

while true; do
    log "开始健康检查..."
    
    # HTTP健康检查
    if curl -f -s --max-time $TIMEOUT "$HEALTH_URL" > /dev/null 2>&1; then
        log_success "HTTP健康检查通过"
        
        # 重置失败计数
        FAILED_COUNT=0
        
        # 检查服务状态
        if systemctl is-active --quiet "${PROJECT_NAME}"; then
            log_success "服务运行正常"
        else
            log_error "服务未运行"
            alert "服务未运行" "systemctl status ${PROJECT_NAME}"
        fi
        
        # 检查Nginx状态
        if systemctl is-active --quiet nginx; then
            log_success "Nginx运行正常"
        else
            log_error "Nginx未运行"
            alert "Nginx未运行" "systemctl status nginx"
        fi
        
        # 检查磁盘空间
        DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
        if [ "$DISK_USAGE" -gt 80 ]; then
            log_warning "磁盘空间使用率: ${DISK_USAGE}%"
        else
            log "磁盘空间正常: ${DISK_USAGE}%"
        fi
        
        # 检查内存使用
        MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
        if [ "$MEM_USAGE" -gt 90 ]; then
            log_warning "内存使用率: ${MEM_USAGE}%"
        else
            log "内存使用正常: ${MEM_USAGE}%"
        fi
        
        # 检查数据库
        if [ -f "/var/www/${PROJECT_NAME}/current/users.db" ]; then
            DB_SIZE=$(du -h "/var/www/${PROJECT_NAME}/current/users.db" | cut -f1)
            log "数据库正常，大小: $DB_SIZE"
        else
            log_error "数据库文件不存在"
        fi
        
        log_success "所有检查项正常"
        
    else
        log_error "HTTP健康检查失败"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        
        log "连续失败次数: $FAILED_COUNT/$ALERT_THRESHOLD"
        
        if [ "$FAILED_COUNT" -ge "$ALERT_THRESHOLD" ]; then
            alert "健康检查连续失败${FAILED_COUNT}次" "应用可能存在严重问题"
            FAILED_COUNT=0
        fi
        
        # 尝试重启服务
        log_warning "尝试重启服务..."
        systemctl restart "${PROJECT_NAME}" || true
        sleep 5
    fi
    
    log "等待下一次检查..."
    echo "----------------------------------------"
    sleep 60  # 每分钟检查一次
done

# 告警函数
alert() {
    local message="$1"
    local details="$2"
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local alert_message="[${timestamp}] 告警: ${message}"
    
    echo "$alert_message" >> "$ALERT_LOG"
    log_error "$alert_message"
    
    # 这里可以添加邮件、Slack等通知方式
    # send_email "$message" "$details"
    # send_slack "$message"
    
    # 记录到系统日志
    logger -t health_check -p local0.warning "$message"
}
