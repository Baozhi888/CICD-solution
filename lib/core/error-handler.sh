#!/bin/bash

# 统一错误处理机制
# 提供标准化的错误处理、日志记录和恢复机制

# 错误码定义
readonly E_SUCCESS=0
readonly E_GENERAL=1
readonly E_CONFIG=2
readonly E_PERMISSION=3
readonly E_FILE_NOT_FOUND=4
readonly E_INVALID_PARAM=5
readonly E_COMMAND_FAILED=6
readonly E_TIMEOUT=7
readonly E_NETWORK=8
readonly E_DEPLOYMENT=9
readonly E_VALIDATION=10

# 错误消息映射
declare -A ERROR_MESSAGES
ERROR_MESSAGES[$E_SUCCESS]="成功"
ERROR_MESSAGES[$E_GENERAL]="一般错误"
ERROR_MESSAGES[$E_CONFIG]="配置错误"
ERROR_MESSAGES[$E_PERMISSION]="权限不足"
ERROR_MESSAGES[$E_FILE_NOT_FOUND]="文件未找到"
ERROR_MESSAGES[$E_INVALID_PARAM]="无效参数"
ERROR_MESSAGES[$E_COMMAND_FAILED]="命令执行失败"
ERROR_MESSAGES[$E_TIMEOUT]="操作超时"
ERROR_MESSAGES[$E_NETWORK]="网络错误"
ERROR_MESSAGES[$E_DEPLOYMENT]="部署失败"
ERROR_MESSAGES[$E_VALIDATION]="验证失败"

# 错误处理配置
ERROR_HANDLER_ENABLED=${ERROR_HANDLER_ENABLED:-true}
ERROR_LOG_FILE="${ERROR_LOG_FILE:-/tmp/cicd-errors.log}"
ERROR_NOTIFICATION_ENABLED=${ERROR_NOTIFICATION_ENABLED:-false}
ERROR_MAX_RETRIES=${ERROR_MAX_RETRIES:-3}
ERROR_RETRY_DELAY=${ERROR_RETRY_DELAY:-5}

# 错误上下文存储
ERROR_CONTEXT=()
ERROR_STACK_TRACE=()

# 初始化错误处理器
init_error_handler() {
    # 确保日志目录存在
    mkdir -p "$(dirname "$ERROR_LOG_FILE")" 2>/dev/null || true
    
    # 设置错误陷阱
    trap 'handle_error $?' ERR
    trap 'handle_interrupt' INT TERM
    
    # 初始化错误上下文
    ERROR_CONTEXT=("script:$0")
    ERROR_STACK_TRACE=()
}

# 处理错误
handle_error() {
    local exit_code=$1
    local line_number=$2
    local command_name=$3
    
    # 如果错误处理器被禁用，直接退出
    [ "$ERROR_HANDLER_ENABLED" != "true" ] && exit $exit_code
    
    # 获取错误信息
    local error_message="错误码: $exit_code (${ERROR_MESSAGES[$exit_code]:-"未知错误"})"
    [ -n "$line_number" ] && error_message="$error_message, 行号: $line_number"
    [ -n "$command_name" ] && error_message="$error_message, 命令: $command_name"
    
    # 记录错误上下文
    error_message="$error_message"
    [ ${#ERROR_CONTEXT[@]} -gt 0 ] && error_message="$error_message, 上下文: ${ERROR_CONTEXT[*]}"
    
    # 记录错误
    log_error "$error_message"
    
    # 记录到错误日志文件
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $error_message" >> "$ERROR_LOG_FILE"
    
    # 记录堆栈跟踪
    if [ ${#ERROR_STACK_TRACE[@]} -gt 0 ]; then
        echo "堆栈跟踪:" >> "$ERROR_LOG_FILE"
        for trace in "${ERROR_STACK_TRACE[@]}"; do
            echo "  at $trace" >> "$ERROR_LOG_FILE"
        done
    fi
    
    # 发送通知（如果启用）
    if [ "$ERROR_NOTIFICATION_ENABLED" = "true" ]; then
        send_error_notification "$error_message" "$exit_code"
    fi
    
    # 尝试错误恢复
    attempt_error_recovery "$exit_code"
    
    # 退出
    exit $exit_code
}

# 处理中断信号
handle_interrupt() {
    log_warn "接收到中断信号，正在清理..."
    cleanup_on_exit
    exit $E_GENERAL
}

# 添加错误上下文
push_error_context() {
    local context="$1"
    ERROR_CONTEXT+=("$context")
}

# 移除错误上下文
pop_error_context() {
    unset 'ERROR_CONTEXT[${#ERROR_CONTEXT[@]}-1]'
}

# 添加堆栈跟踪
push_stack_trace() {
    local trace="$1"
    ERROR_STACK_TRACE+=("$trace")
}

# 发送错误通知
send_error_notification() {
    local error_message="$1"
    local error_code="$2"
    
    # 这里可以集成各种通知方式
    # 例如：邮件、Slack、Webhook等
    
    log_info "发送错误通知: $error_message"
    
    # 示例：发送到 Slack
    if [ -n "${SLACK_WEBHOOK_URL:-}" ]; then
        curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"CI/CD 错误: $error_message\"}" \
            "$SLACK_WEBHOOK_URL" >/dev/null 2>&1 || true
    fi
}

# 尝试错误恢复
attempt_error_recovery() {
    local error_code=$1
    
    case $error_code in
        $E_CONFIG)
            log_info "尝试恢复配置错误..."
            # 尝试重新加载配置
            if command -v reload_config >/dev/null 2>&1; then
                reload_config || log_error "配置恢复失败"
            fi
            ;;
        $E_DEPLOYMENT)
            log_info "尝试回滚部署..."
            # 尝试回滚
            if command -v rollback_deployment >/dev/null 2>&1; then
                rollback_deployment || log_error "部署回滚失败"
            fi
            ;;
        *)
            log_debug "错误码 $error_code 没有特定的恢复策略"
            ;;
    esac
}

# 带重试的命令执行
execute_with_retry() {
    local command="$1"
    local max_retries="${2:-$ERROR_MAX_RETRIES}"
    local retry_delay="${3:-$ERROR_RETRY_DELAY}"
    local attempt=1
    
    while [ $attempt -le $max_retries ]; do
        log_debug "执行命令 (尝试 $attempt/$max_retries): $command"
        
        if eval "$command"; then
            return 0
        fi
        
        if [ $attempt -lt $max_retries ]; then
            log_warn "命令失败，$retry_delay 秒后重试..."
            sleep $retry_delay
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "命令执行失败，已达到最大重试次数"
    return $E_COMMAND_FAILED
}

# 带超时的命令执行
execute_with_timeout() {
    local command="$1"
    local timeout_seconds="$2"
    
    log_debug "执行命令 (超时 $timeout_seconds 秒): $command"
    
    # 使用 timeout 命令
    if timeout "$timeout_seconds" bash -c "$command"; then
        return 0
    else
        local exit_code=$?
        if [ $exit_code -eq 124 ]; then
            log_error "命令执行超时"
            return $E_TIMEOUT
        else
            log_error "命令执行失败，退出码: $exit_code"
            return $E_COMMAND_FAILED
        fi
    fi
}

# 验证必需的命令
validate_required_commands() {
    local commands=("$@")
    local missing_commands=()
    
    for cmd in "${commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "缺少必需的命令: ${missing_commands[*]}"
        return $E_COMMAND_FAILED
    fi
    
    return 0
}

# 验证文件存在
validate_required_files() {
    local files=("$@")
    local missing_files=()
    
    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺少必需的文件: ${missing_files[*]}"
        return $E_FILE_NOT_FOUND
    fi
    
    return 0
}

# 安全退出
safe_exit() {
    local exit_code=${1:-$E_SUCCESS}
    
    # 执行清理
    cleanup_on_exit
    
    # 退出
    exit $exit_code
}

# 清理函数（可由具体脚本覆盖）
cleanup_on_exit() {
    log_debug "执行清理操作..."
    # 默认不做任何事，由具体脚本实现
}

# 错误处理包装器
with_error_handling() {
    local function_name="$1"
    shift
    
    # 设置错误上下文
    push_error_context "function:$function_name"
    push_stack_trace "$function_name(${*@Q})"
    
    # 执行函数
    "$@"
    
    # 清理上下文
    pop_error_context
}

# 导出函数和变量
export -f init_error_handler handle_error handle_interrupt
export -f push_error_context pop_error_context push_stack_trace
export -f send_error_notification attempt_error_recovery
export -f execute_with_retry execute_with_timeout
export -f validate_required_commands validate_required_files
export -f safe_exit cleanup_on_exit with_error_handling

export E_SUCCESS E_GENERAL E_CONFIG E_PERMISSION
export E_FILE_NOT_FOUND E_INVALID_PARAM E_COMMAND_FAILED
export E_TIMEOUT E_NETWORK E_DEPLOYMENT E_VALIDATION
export ERROR_MESSAGES ERROR_HANDLER_ENABLED ERROR_LOG_FILE
export ERROR_NOTIFICATION_ENABLED ERROR_MAX_RETRIES ERROR_RETRY_DELAY