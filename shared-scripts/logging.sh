#!/bin/bash

# 日志记录库
# 提供统一的日志记录功能
# 支持日志级别控制、文件记录和模块化使用

# 颜色定义
LOG_RED='\033[0;31m'
LOG_GREEN='\033[0;32m'
LOG_YELLOW='\033[1;33m'
LOG_BLUE='\033[0;34m'
LOG_PURPLE='\033[0;35m'
LOG_CYAN='\033[0;36m'
LOG_WHITE='\033[1;37m'
LOG_NC='\033[0m' # No Color

# 日志级别
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# 默认日志级别
LOG_LEVEL=${LOG_LEVEL:-$LOG_LEVEL_INFO}

# 默认日志文件
DEFAULT_LOG_FILE="${DEFAULT_LOG_FILE:-/tmp/cicd.log}"

# 模块名称
LOG_MODULE_NAME="${LOG_MODULE_NAME:-CI/CD}"

# 日志函数
log_debug() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_DEBUG ]; then
        echo -e "${LOG_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${LOG_MODULE_NAME}] [DEBUG]${LOG_NC} $1" >&2
        log_to_file "[$LOG_MODULE_NAME] [DEBUG] $1" "$DEFAULT_LOG_FILE"
    fi
}

log_info() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_INFO ]; then
        echo -e "${LOG_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${LOG_MODULE_NAME}] [INFO]${LOG_NC} $1" >&2
        log_to_file "[$LOG_MODULE_NAME] [INFO] $1" "$DEFAULT_LOG_FILE"
    fi
}

log_warn() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_WARN ]; then
        echo -e "${LOG_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${LOG_MODULE_NAME}] [WARN]${LOG_NC} $1" >&2
        log_to_file "[$LOG_MODULE_NAME] [WARN] $1" "$DEFAULT_LOG_FILE"
    fi
}

log_error() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_ERROR ]; then
        echo -e "${LOG_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${LOG_MODULE_NAME}] [ERROR]${LOG_NC} $1" >&2
        log_to_file "[$LOG_MODULE_NAME] [ERROR] $1" "$DEFAULT_LOG_FILE"
    fi
}

log_fatal() {
    if [ $LOG_LEVEL -le $LOG_LEVEL_FATAL ]; then
        echo -e "${LOG_PURPLE}[$(date +'%Y-%m-%d %H:%M:%S')] [${LOG_MODULE_NAME}] [FATAL]${LOG_NC} $1" >&2
        log_to_file "[$LOG_MODULE_NAME] [FATAL] $1" "$DEFAULT_LOG_FILE"
    fi
}

# 设置日志级别
set_log_level() {
    case $1 in
        debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
        info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
        warn) LOG_LEVEL=$LOG_LEVEL_WARN ;;
        error) LOG_LEVEL=$LOG_LEVEL_ERROR ;;
        fatal) LOG_LEVEL=$LOG_LEVEL_FATAL ;;
        *) log_warn "未知的日志级别: $1，使用默认级别 INFO" ;;
    esac
    log_debug "日志级别设置为: $1"
}

# 日志文件记录
log_to_file() {
    local message="$1"
    local log_file="$2"
    
    if [ -n "$log_file" ]; then
        # 确保日志目录存在
        mkdir -p "$(dirname "$log_file")" 2>/dev/null || true
        echo "$(date +'%Y-%m-%d %H:%M:%S') $message" >> "$log_file"
    fi
}

# 设置模块名称
set_log_module() {
    LOG_MODULE_NAME="$1"
    log_debug "设置日志模块名称为: $LOG_MODULE_NAME"
}