#!/bin/bash

# 指数退避重试机制实现
# 支持最大重试次数、基础退避时间、最大退避时间、抖动等配置

set -euo pipefail

# 默认参数
MAX_RETRIES=3
BASE_DELAY=1  # 基础退避时间（秒）
MAX_DELAY=60  # 最大退避时间（秒）
JITTER=true   # 是否启用抖动
BACKOFF_FACTOR=2  # 退避因子

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] -- <命令>

指数退避重试机制实现

选项:
  -m, --max-retries NUM     最大重试次数 [默认: $MAX_RETRIES]
  -b, --base-delay SECONDS  基础退避时间（秒） [默认: $BASE_DELAY]
  -x, --max-delay SECONDS   最大退避时间（秒） [默认: $MAX_DELAY]
  -j, --jitter BOOL         是否启用抖动 (true/false) [默认: $JITTER]
  -f, --factor NUM          退避因子 [默认: $BACKOFF_FACTOR]
  -h, --help                显示此帮助信息

示例:
  $0 --max-retries 5 -- curl -f https://example.com/health
  $0 -m 3 -b 2 -x 30 -- kubectl rollout status deployment/myapp
  $0 --jitter false -- npm test

EOF
}

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--max-retries)
                MAX_RETRIES="$2"
                shift 2
                ;;
            -b|--base-delay)
                BASE_DELAY="$2"
                shift 2
                ;;
            -x|--max-delay)
                MAX_DELAY="$2"
                shift 2
                ;;
            -j|--jitter)
                JITTER="$2"
                shift 2
                ;;
            -f|--factor)
                BACKOFF_FACTOR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --)
                shift
                COMMAND=("$@")
                break
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 计算退避时间
calculate_backoff() {
    local attempt=$1
    local delay=$((BASE_DELAY * BACKOFF_FACTOR ** attempt))
    
    # 限制最大退避时间
    if [ $delay -gt $MAX_DELAY ]; then
        delay=$MAX_DELAY
    fi
    
    # 添加抖动
    if [ "$JITTER" = true ]; then
        local jitter=$((RANDOM % delay))
        delay=$((delay + jitter))
    fi
    
    echo $delay
}

# 执行带重试的命令
execute_with_retry() {
    local attempt=0
    local success=false
    
    while [ $attempt -lt $MAX_RETRIES ]; do
        if [ $attempt -gt 0 ]; then
            local backoff=$(calculate_backoff $((attempt-1)))
            log_warn "第 $attempt 次重试，等待 ${backoff} 秒后执行..."
            sleep $backoff
        fi
        
        log "执行命令: ${COMMAND[*]}"
        
        # 执行命令
        if "${COMMAND[@]}"; then
            success=true
            break
        else
            local exit_code=$?
            log_error "命令执行失败，退出码: $exit_code"
            attempt=$((attempt + 1))
        fi
    done
    
    if [ "$success" = true ]; then
        log "命令执行成功"
        return 0
    else
        log_error "命令执行失败，已达到最大重试次数: $MAX_RETRIES"
        return 1
    fi
}

# 主函数
main() {
    # 解析参数
    parse_args "$@"
    
    # 验证必要参数
    if [ ${#COMMAND[@]} -eq 0 ]; then
        log_error "必须指定要执行的命令"
        show_help
        exit 1
    fi
    
    # 执行带重试的命令
    execute_with_retry
}

# 如果脚本直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi