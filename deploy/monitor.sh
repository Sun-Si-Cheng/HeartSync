#!/bin/bash

################################################################################
# HeartSync - 监控脚本
# 监控应用性能、日志和资源使用情况
################################################################################

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 配置
PROJECT_NAME="heart_sync"
PROJECT_DIR="/var/www/${PROJECT_NAME}"
LOG_DIR="${PROJECT_DIR}/logs"
MONITOR_LOG="${LOG_DIR}/monitor_$(date +%Y%m%d).log"

# 日志函数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$MONITOR_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# 创建日志目录
mkdir -p "$LOG_DIR"

# 显示系统资源
show_resources() {
    echo ""
    log "系统资源使用情况："
    echo "========================================"
    
    # CPU使用率
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}')
    echo "CPU使用率: $CPU_USAGE"
    
    # 内存使用
    MEM_INFO=$(free -h)
    echo "$MEM_INFO"
    
    # 磁盘使用
    DISK_INFO=$(df -h / | tail -1)
    echo "磁盘使用: $DISK_INFO"
    
    # 负载平均
    LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
    echo "负载平均:$LOAD_AVG"
    echo ""
}

# 显示服务状态
show_services() {
    log "服务状态："
    echo "========================================"
    
    systemctl status "${PROJECT_NAME}" --no-pager -l | head -n 15
    echo ""
    
    systemctl status nginx --no-pager -l | head -n 10
    echo ""
}

# 显示最近日志
show_recent_logs() {
    log "最近的应用日志（最后20行）："
    echo "========================================"
    
    if [ -f "${PROJECT_DIR}/logs/app.log" ]; then
        tail -n 20 "${PROJECT_DIR}/logs/app.log"
    else
        log_warning "应用日志文件不存在"
    fi
    echo ""
}

# 显示错误日志
show_error_logs() {
    log "最近的错误日志："
    echo "========================================"
    
    # 搜索应用日志中的错误
    if [ -f "${PROJECT_DIR}/logs/app.log" ]; then
        grep -i "error\|exception\|traceback" "${PROJECT_DIR}/logs/app.log" | tail -n 20 || log_warning "没有找到错误日志"
    else
        log_warning "应用日志文件不存在"
    fi
    echo ""
    
    # 显示系统日志
    log "系统服务日志（最后10行）："
    journalctl -u "${PROJECT_NAME}" -n 10 --no-pager
    echo ""
}

# 显示访问统计
show_access_stats() {
    log "访问统计："
    echo "========================================"
    
    # 统计Nginx访问日志
    local nginx_log="/var/log/nginx/${PROJECT_NAME}.access.log"
    
    if [ -f "$nginx_log" ]; then
        echo "总请求数（今日）: $(grep $(date +%d/%b/%Y) $nginx_log | wc -l)"
        echo "唯一IP数（今日）: $(grep $(date +%d/%b/%Y) $nginx_log | awk '{print $1}' | sort | uniq | wc -l)"
        echo "错误请求数（今日）: $(grep $(date +%d/%b/%Y) $nginx_log | grep -E ' 4[0-9]{2} | 5[0-9]{2} ' | wc -l)"
        
        echo ""
        echo "最活跃的IP（前5）:"
        grep $(date +%d/%b/%Y) $nginx_log | awk '{print $1}' | sort | uniq -c | sort -rn | head -n 5 | awk '{print "  " $2 " - " $1 " 次"}'
    else
        log_warning "Nginx访问日志不存在"
    fi
    echo ""
}

# 显示数据库统计
show_database_stats() {
    log "数据库统计："
    echo "========================================"
    
    local db_file="${PROJECT_DIR}/current/users.db"
    
    if [ -f "$db_file" ]; then
        echo "数据库大小: $(du -h $db_file | cut -f1)"
        echo "数据库修改时间: $(stat -c %y $db_file)"
        
        if command -v sqlite3 &> /dev/null; then
            echo ""
            echo "用户表记录数:"
            sqlite3 "$db_file" "SELECT COUNT(*) FROM users;" 2>/dev/null || echo "  无法查询"
            
            echo ""
            echo "最近注册的用户（前5）:"
            sqlite3 "$db_file" "SELECT username, email, created_at FROM users ORDER BY created_at DESC LIMIT 5;" 2>/dev/null || echo "  无法查询"
        fi
    else
        log_warning "数据库文件不存在"
    fi
    echo ""
}

# 显示网络连接
show_network() {
    log "网络连接："
    echo "========================================"
    
    # 显示当前连接数
    local connections=$(netstat -an | grep :5000 | grep ESTABLISHED | wc -l)
    echo "当前活动连接数: $connections"
    
    # 显示监听端口
    echo ""
    echo "监听端口:"
    netstat -tlnp 2>/dev/null | grep -E ':5000|:80|:443' || ss -tlnp 2>/dev/null | grep -E ':5000|:80|:443'
    echo ""
}

# 性能报告
show_performance_report() {
    log "性能报告："
    echo "========================================"
    
    # 响应时间
    local response_time=$(curl -o /dev/null -s -w '%{time_total}' http://localhost:5000/ 2>/dev/null || echo "N/A")
    echo "主页响应时间: ${response_time}s"
    
    # 健康检查
    local health_status=$(curl -f -s http://localhost:5000/health > /dev/null 2>&1 && echo "健康" || echo "不健康")
    echo "健康状态: $health_status"
    
    # 运行时间
    local uptime=$(systemctl show ${PROJECT_NAME} --property=ActiveEnterTimestamp | cut -d'=' -f2)
    if [ -n "$uptime" ]; then
        echo "服务启动时间: $uptime"
    fi
    echo ""
}

# 生成监控报告
generate_report() {
    log "========================================"
    log "  HeartSync 监控报告"
    log "========================================"
    log "生成时间: $(date)"
    echo ""
    
    show_resources
    show_services
    show_performance_report
    show_network
    show_database_stats
    show_access_stats
    show_recent_logs
    show_error_logs
    
    log "========================================"
    log "报告生成完成"
    log "========================================"
}

# 实时监控
monitor_realtime() {
    log "开始实时监控...（按Ctrl+C退出）"
    
    while true; do
        clear
        echo "========================================"
        echo "  HeartSync 实时监控"
        echo "========================================"
        echo "最后更新: $(date)"
        echo ""
        
        show_resources
        show_performance_report
        
        echo ""
        echo "最近5条日志:"
        if [ -f "${PROJECT_DIR}/logs/app.log" ]; then
            tail -n 5 "${PROJECT_DIR}/logs/app.log"
        fi
        
        sleep 5
    done
}

# 主函数
main() {
    case "$1" in
        --all|report)
            generate_report
            ;;
        --realtime|live)
            monitor_realtime
            ;;
        --resources)
            show_resources
            ;;
        --services)
            show_services
            ;;
        --logs)
            show_recent_logs
            ;;
        --errors)
            show_error_logs
            ;;
        --stats)
            show_access_stats
            ;;
        --database)
            show_database_stats
            ;;
        --performance)
            show_performance_report
            ;;
        *)
            echo "HeartSync 监控脚本"
            echo ""
            echo "用法: $0 [选项]"
            echo ""
            echo "选项:"
            echo "  --all, report     生成完整监控报告"
            echo "  --realtime, live  实时监控模式"
            echo "  --resources       显示系统资源"
            echo "  --services        显示服务状态"
            echo "  --logs            显示最近日志"
            echo "  --errors          显示错误日志"
            echo "  --stats           显示访问统计"
            echo "  --database        显示数据库统计"
            echo "  --performance     显示性能报告"
            echo ""
            echo "示例:"
            echo "  $0 --all"
            echo "  $0 --realtime"
            ;;
    esac
}

main "$@"
