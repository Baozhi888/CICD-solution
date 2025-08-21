#!/bin/bash

# 增强的日志管理功能
# 提供日志轮转、清理、归档等高级功能

# 日志管理配置
LOG_ROTATE_ENABLED=${LOG_ROTATE_ENABLED:-true}
LOG_ROTATE_SIZE=${LOG_ROTATE_SIZE:-10485760}  # 10MB
LOG_ROTATE_COUNT=${LOG_ROTATE_COUNT:-5}
LOG_CLEANUP_ENABLED=${LOG_CLEANUP_ENABLED:-true}
LOG_CLEANUP_DAYS=${LOG_CLEANUP_DAYS:-30}
LOG_COMPRESS_ENABLED=${LOG_COMPRESS_ENABLED:-true}
LOG_ARCHIVE_DIR="${LOG_ARCHIVE_DIR:-/var/log/cicd/archive}"

# 日志格式配置
LOG_FORMAT="${LOG_FORMAT:-standard}"  # standard, json, structured
LOG_TIMESTAMP_FORMAT="${LOG_TIMESTAMP_FORMAT:-%Y-%m-%d %H:%M:%S}"
LOG_INCLUDE_STACK_TRACE="${LOG_INCLUDE_STACK_TRACE:-false}"

# 日志文件句柄
declare -A LOG_FILE_HANDLES

# 初始化日志管理
init_log_management() {
    # 确保日志目录存在
    mkdir -p "$(dirname "$DEFAULT_LOG_FILE")" 2>/dev/null || true
    mkdir -p "$LOG_ARCHIVE_DIR" 2>/dev/null || true
    
    # 检查是否需要轮转
    if [ "$LOG_ROTATE_ENABLED" = "true" ]; then
        check_log_rotation "$DEFAULT_LOG_FILE"
    fi
    
    # 清理旧日志
    if [ "$LOG_CLEANUP_ENABLED" = "true" ]; then
        cleanup_old_logs
    fi
}

# 检查并执行日志轮转
check_log_rotation() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        return 0
    fi
    
    local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)
    
    if [ $file_size -gt $LOG_ROTATE_SIZE ]; then
        rotate_log "$log_file"
    fi
}

# 执行日志轮转
rotate_log() {
    local log_file="$1"
    local log_dir=$(dirname "$log_file")
    local log_name=$(basename "$log_file")
    
    log_info "轮转日志文件: $log_file"
    
    # 移动旧日志
    for i in $(seq $((LOG_ROTATE_COUNT - 1)) -1 1); do
        if [ -f "$log_file.$i" ]; then
            if [ "$LOG_COMPRESS_ENABLED" = "true" ] && [ $i -eq 1 ]; then
                gzip "$log_file.$i"
                mv "$log_file.$i.gz" "$log_file.$((i + 1)).gz"
            else
                mv "$log_file.$i" "$log_file.$((i + 1))"
            fi
        fi
    done
    
    # 移动当前日志
    if [ -f "$log_file" ]; then
        mv "$log_file" "$log_file.1"
    fi
    
    # 归档最旧的日志
    if [ $LOG_ROTATE_COUNT -gt 0 ] && [ -f "$log_file.$LOG_ROTATE_COUNT" ]; then
        archive_log "$log_file.$LOG_ROTATE_COUNT"
    fi
    
    # 创建新的日志文件
    touch "$log_file"
    
    # 设置适当的权限
    chmod 640 "$log_file" 2>/dev/null || true
}

# 归档日志文件
archive_log() {
    local log_file="$1"
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local log_name=$(basename "$log_file")
    local archive_file="$LOG_ARCHIVE_DIR/${log_name}.${timestamp}.gz"
    
    log_debug "归档日志文件: $log_file -> $archive_file"
    
    if [ "$LOG_COMPRESS_ENABLED" = "true" ] && [[ "$log_file" != *.gz ]]; then
        gzip -c "$log_file" > "$archive_file"
        rm -f "$log_file"
    else
        mv "$log_file" "$archive_file"
    fi
}

# 清理旧日志
cleanup_old_logs() {
    log_debug "清理 $LOG_CLEANUP_DAYS 天前的日志"
    
    # 清理主日志目录
    if [ -n "$(dirname "$DEFAULT_LOG_FILE")" ]; then
        find "$(dirname "$DEFAULT_LOG_FILE")" -name "*.log*" -type f -mtime +$LOG_CLEANUP_DAYS -delete 2>/dev/null || true
    fi
    
    # 清理归档日志
    find "$LOG_ARCHIVE_DIR" -name "*.gz" -type f -mtime +$((LOG_CLEANUP_DAYS * 2)) -delete 2>/dev/null || true
}

# 增强的日志记录函数
log_with_format() {
    local level="$1"
    local message="$2"
    shift 2
    
    # 格式化消息
    local formatted_message=""
    
    case "$LOG_FORMAT" in
        "json")
            formatted_message=$(format_json_log "$level" "$message" "$@")
            ;;
        "structured")
            formatted_message=$(format_structured_log "$level" "$message" "$@")
            ;;
        *)
            formatted_message=$(format_standard_log "$level" "$message")
            ;;
    esac
    
    # 输出到控制台
    echo -e "$formatted_message" >&2
    
    # 输出到文件
    log_to_file "$formatted_message" "$DEFAULT_LOG_FILE"
    
    # 检查是否需要轮转
    if [ "$LOG_ROTATE_ENABLED" = "true" ]; then
        check_log_rotation "$DEFAULT_LOG_FILE"
    fi
}

# JSON 格式日志
format_json_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")
    local module_name="$LOG_MODULE_NAME"
    
    # JSON 转义消息
    message_json=$(echo "$message" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')
    
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"module\":\"$module_name\",\"message\":\"$message_json\"}"
}

# 结构化日志
format_structured_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")
    local module_name="$LOG_MODULE_NAME"
    
    echo "[$timestamp] [$level] [$module_name] $message"
}

# 标准日志格式（带颜色）
format_standard_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"$LOG_TIMESTAMP_FORMAT")
    local module_name="$LOG_MODULE_NAME"
    local color=""
    
    case "$level" in
        "DEBUG") color="$LOG_BLUE" ;;
        "INFO") color="$LOG_GREEN" ;;
        "WARN") color="$LOG_YELLOW" ;;
        "ERROR") color="$LOG_RED" ;;
        "FATAL") color="$LOG_PURPLE" ;;
    esac
    
    echo "${color}[$timestamp] [$module_name] [$level]${LOG_NC} $message"
}

# 增强的日志文件记录
log_to_file() {
    local message="$1"
    local log_file="$2"
    
    if [ -n "$log_file" ]; then
        # 确保日志目录存在
        mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
        
        # 移除颜色代码
        local clean_message=$(echo "$message" | sed 's/\x1b\[[0-9;]*m//g')
        
        # 写入文件
        echo "$clean_message" >> "$log_file"
    fi
}

# 打开额外的日志文件
open_log_file() {
    local name="$1"
    local path="$2"
    
    # 确保目录存在
    mkdir -p "$(dirname "$path")" 2>/dev/null || true
    
    # 创建日志文件
    touch "$path"
    
    # 存储句柄
    LOG_FILE_HANDLES["$name"]="$path"
    
    log_debug "打开日志文件: $name -> $path"
}

# 关闭日志文件
close_log_file() {
    local name="$1"
    
    if [ -n "${LOG_FILE_HANDLES[$name]}" ]; then
        log_debug "关闭日志文件: $name"
        unset "LOG_FILE_HANDLES[$name]"
    fi
}

# 记录到特定日志文件
log_to_file_handle() {
    local handle_name="$1"
    local level="$2"
    local message="$3"
    
    if [ -n "${LOG_FILE_HANDLES[$handle_name]}" ]; then
        local log_file="${LOG_FILE_HANDLES[$handle_name]}"
        local formatted_message=$(format_standard_log "$level" "$message")
        log_to_file "$formatted_message" "$log_file"
    fi
}

# 日志查询功能
query_logs() {
    local query="$1"
    local log_file="${2:-$DEFAULT_LOG_FILE}"
    local days="${3:-7}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    # 查询最近的日志
    if command -v rg >/dev/null 2>&1; then
        rg -A 2 -B 2 "$query" "$log_file" --since "$days days ago"
    elif command -v grep >/dev/null 2>&1; then
        # 查找指定天数内的日志
        local since_date=$(date -d "$days days ago" +"%Y-%m-%d")
        awk -v since="$since_date" -v query="$query" '
        $0 >= since && $0 ~ query {
            print;
            for(i=1; i<=2; i++) {
                if(getline > 0) print;
                else break;
            }
        }
        ' "$log_file"
    else
        log_error "未找到日志查询工具"
        return 1
    fi
}

# 日志统计
log_statistics() {
    local log_file="${1:-$DEFAULT_LOG_FILE}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    echo "日志统计信息: $log_file"
    echo "----------------------------------------"
    
    # 总行数
    local total_lines=$(wc -l < "$log_file" 2>/dev/null || echo 0)
    echo "总行数: $total_lines"
    
    # 按级别统计
    for level in DEBUG INFO WARN ERROR FATAL; do
        local count=$(grep -c "\[$level\]" "$log_file" 2>/dev/null || echo 0)
        echo "$level: $count"
    done
    
    # 文件大小
    local size=$(du -h "$log_file" 2>/dev/null | cut -f1 || echo "未知")
    echo "文件大小: $size"
    
    # 最后修改时间
    local last_modified=$(stat -f%Sm -t%Y-%m-%d\ %H:%M:%S "$log_file" 2>/dev/null || stat -c%y "$log_file" 2>/dev/null || echo "未知")
    echo "最后修改: $last_modified"
}

# 重写原始日志函数以使用新功能
log_debug() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        log_with_format "DEBUG" "$@"
    fi
}

log_info() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        log_with_format "INFO" "$@"
    fi
}

log_warn() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
        log_with_format "WARN" "$@"
    fi
}

log_error() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        log_with_format "ERROR" "$@"
        
        # 如果启用堆栈跟踪
        if [ "$LOG_INCLUDE_STACK_TRACE" = "true" ]; then
            local frame=0
            while caller $frame; do
                ((frame++))
            done
        fi
    fi
}

log_fatal() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_FATAL ]; then
        log_with_format "FATAL" "$@"
    fi
}

# 初始化日志管理
init_log_management

# 导出函数
export -f init_log_management check_log_rotation rotate_log
export -f archive_log cleanup_old_logs
export -f log_with_format format_json_log format_structured_log
export -f format_standard_log log_to_file
export -f open_log_file close_log_file log_to_file_handle
export -f query_logs log_statistics
export LOG_ROTATE_ENABLED LOG_ROTATE_SIZE LOG_ROTATE_COUNT
export LOG_CLEANUP_ENABLED LOG_CLEANUP_DAYS LOG_COMPRESS_ENABLED
export LOG_ARCHIVE_DIR LOG_FORMAT LOG_TIMESTAMP_FORMAT
export LOG_INCLUDE_STACK_TRACE LOG_FILE_HANDLES