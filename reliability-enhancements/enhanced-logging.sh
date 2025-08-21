#!/bin/bash

# 增强型日志记录库
# 提供详细的错误日志和上下文信息，支持结构化日志记录

# 导入基础日志库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../scripts/logging.sh"

# 全局变量
CONTEXT_STACK=()
LOG_CORRELATION_ID=""
LOG_CONTEXT_FILE=""

# 生成关联ID
generate_correlation_id() {
    if [ -z "$LOG_CORRELATION_ID" ]; then
        LOG_CORRELATION_ID=$(uuidgen 2>/dev/null || echo "$(date +%s)-$(shuf -i 1000-9999 -n 1)")
    fi
    echo "$LOG_CORRELATION_ID"
}

# 设置关联ID
set_correlation_id() {
    LOG_CORRELATION_ID="$1"
}

# 推入上下文
push_context() {
    local context="$1"
    CONTEXT_STACK+=("$context")
}

# 弹出上下文
pop_context() {
    if [ ${#CONTEXT_STACK[@]} -gt 0 ]; then
        unset CONTEXT_STACK[$((${#CONTEXT_STACK[@]}-1))]
    fi
}

# 获取当前上下文
get_current_context() {
    local context_str=""
    for ctx in "${CONTEXT_STACK[@]}"; do
        if [ -n "$context_str" ]; then
            context_str="$context_str -> $ctx"
        else
            context_str="$ctx"
        fi
    done
    echo "$context_str"
}

# 获取系统信息
get_system_info() {
    local sys_info=""
    sys_info+="host=$(hostname),"
    sys_info+="user=$(whoami),"
    sys_info+="pid=$$,"
    sys_info+="pwd=$(pwd)"
    echo "$sys_info"
}

# 获取环境变量信息
get_env_info() {
    local env_info=""
    # 只记录特定的环境变量
    for var in JOB_NAME BUILD_NUMBER GIT_BRANCH GIT_COMMIT; do
        if [ -n "${!var}" ]; then
            env_info+="$var=${!var},"
        fi
    done
    # 移除末尾的逗号
    env_info=${env_info%,}
    echo "$env_info"
}

# 结构化日志记录
structured_log() {
    local level="$1"
    local message="$2"
    local extra_fields="$3"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local correlation_id=$(generate_correlation_id)
    local context=$(get_current_context)
    local system_info=$(get_system_info)
    local env_info=$(get_env_info)
    
    # 构建结构化日志
    local log_entry="{"
    log_entry+="\"timestamp\":\"$timestamp\","
    log_entry+="\"level\":\"$level\","
    log_entry+="\"correlation_id\":\"$correlation_id\","
    log_entry+="\"message\":\"$message\","
    
    # 添加上下文
    if [ -n "$context" ]; then
        log_entry+="\"context\":\"$context\","
    fi
    
    # 添加系统信息
    if [ -n "$system_info" ]; then
        log_entry+="\"system_info\":\"$system_info\","
    fi
    
    # 添加环境信息
    if [ -n "$env_info" ]; then
        log_entry+="\"env_info\":\"$env_info\","
    fi
    
    # 添加额外字段
    if [ -n "$extra_fields" ]; then
        log_entry+="$extra_fields,"
    fi
    
    # 移除末尾的逗号并关闭JSON对象
    log_entry=${log_entry%,}
    log_entry+="}"
    
    # 输出日志
    echo "$log_entry" >&2
    
    # 如果设置了日志文件，也写入文件
    if [ -n "$LOG_CONTEXT_FILE" ]; then
        echo "$log_entry" >> "$LOG_CONTEXT_FILE"
    fi
}

# 增强型日志函数
log_debug_enhanced() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        structured_log "DEBUG" "$1" "$2"
    fi
}

log_info_enhanced() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        structured_log "INFO" "$1" "$2"
    fi
}

log_warn_enhanced() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
        structured_log "WARN" "$1" "$2"
    fi
}

log_error_enhanced() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        structured_log "ERROR" "$1" "$2"
    fi
}

log_fatal_enhanced() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_FATAL ]; then
        structured_log "FATAL" "$1" "$2"
    fi
}

# 错误处理函数
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command="$3"
    
    local error_fields="\"error_code\":$exit_code,\"line_number\":$line_number,\"failed_command\":\"$command\""
    log_error_enhanced "脚本执行出错" "$error_fields"
    
    # 记录堆栈跟踪
    local stack_trace=""
    local i=0
    while caller $i > /dev/null 2>&1; do
        local caller_info=$(caller $i)
        stack_trace+="[$caller_info] "
        ((i++))
    done
    
    if [ -n "$stack_trace" ]; then
        local trace_fields="\"stack_trace\":\"$stack_trace\""
        log_debug_enhanced "堆栈跟踪信息" "$trace_fields"
    fi
}

# 设置错误处理陷阱
set_error_trap() {
    set -Eeuo pipefail
    trap 'handle_error $? $LINENO "$BASH_COMMAND"' ERR
}

# 创建临时日志上下文文件
create_log_context() {
    LOG_CONTEXT_FILE=$(mktemp)
    echo "创建日志上下文文件: $LOG_CONTEXT_FILE"
}

# 清理日志上下文文件
cleanup_log_context() {
    if [ -n "$LOG_CONTEXT_FILE" ] && [ -f "$LOG_CONTEXT_FILE" ]; then
        rm -f "$LOG_CONTEXT_FILE"
        LOG_CONTEXT_FILE=""
    fi
}

# 导出关键函数
export -f generate_correlation_id
export -f set_correlation_id
export -f push_context
export -f pop_context
export -f structured_log
export -f log_debug_enhanced
export -f log_info_enhanced
export -f log_warn_enhanced
export -f log_error_enhanced
export -f log_fatal_enhanced
export -f handle_error
export -f set_error_trap
export -f create_log_context
export -f cleanup_log_context