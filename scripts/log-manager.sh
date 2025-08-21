#!/bin/bash

# 日志管理工具
# 提供日志查询、统计、清理等功能

# 加载核心库
source "$(dirname "$0")/../lib/core-loader.sh"

# 设置模块名称
set_log_module "LogManager"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项] <命令>

CI/CD 日志管理工具

命令:
  query <pattern> [days]    查询日志
  stats [file]              显示日志统计
  rotate [file]             手动轮转日志
  clean [days]              清理旧日志
  archive [file]            归档日志
  tail [file] [lines]       查看日志末尾
  watch [file]              实时监控日志
  export [file] [format]    导出日志

选项:
  -v, --verbose             详细输出
  -f, --file FILE           指定日志文件
  -d, --dir DIR             日志目录
  -h, --help                显示此帮助信息

环境变量:
  LOG_FILE                  默认日志文件
  LOG_ARCHIVE_DIR           归档目录
  LOG_CLEANUP_DAYS          清理天数

示例:
  $0 query "ERROR" 7          # 查询最近7天的错误日志
  $0 stats                    # 显示默认日志统计
  $0 rotate -f /var/log/app.log  # 轮转指定日志文件
  $0 clean 30                # 清理30天前的日志
EOF
}

# 查询日志
cmd_query() {
    local pattern="$1"
    local days="${2:-7}"
    local log_file="${LOG_FILE:-$DEFAULT_LOG_FILE}"
    
    if [ -z "$pattern" ]; then
        log_error "请指定查询模式"
        return 1
    fi
    
    log_info "查询日志: 模式='$pattern', 天数=$days"
    query_logs "$pattern" "$log_file" "$days"
}

# 显示统计
cmd_stats() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    
    log_info "显示日志统计: $log_file"
    log_statistics "$log_file"
}

# 轮转日志
cmd_rotate() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_info "轮转日志: $log_file"
    rotate_log "$log_file"
}

# 清理日志
cmd_clean() {
    local days="${1:-$LOG_CLEANUP_DAYS}"
    
    if [ -z "$days" ]; then
        log_error "请指定清理天数或设置 LOG_CLEANUP_DAYS 环境变量"
        return 1
    fi
    
    log_info "清理 $days 天前的日志"
    LOG_CLEANUP_DAYS="$days" cleanup_old_logs
}

# 归档日志
cmd_archive() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_info "归档日志: $log_file"
    archive_log "$log_file"
}

# 查看日志末尾
cmd_tail() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    local lines="${2:-50}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    tail -n "$lines" "$log_file"
}

# 实时监控日志
cmd_watch() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_info "监控日志文件: $log_file (按 Ctrl+C 退出)"
    tail -f "$log_file"
}

# 导出日志
cmd_export() {
    local log_file="${1:-${LOG_FILE:-$DEFAULT_LOG_FILE}}"
    local format="${2:-json}"
    local output_file="${log_file}.${format}.export"
    
    if [ ! -f "$log_file" ]; then
        log_error "日志文件不存在: $log_file"
        return 1
    fi
    
    log_info "导出日志: $log_file -> $output_file (格式: $format)"
    
    case "$format" in
        "json")
            # 转换为 JSON 格式
            echo "[" > "$output_file"
            local first=true
            while IFS= read -r line; do
                if [[ $line =~ ^\[([^\]]+)\]\ \[([^\]]+)\]\ \[([^\]]+)\]\ (.*)$ ]]; then
                    if [ "$first" = true ]; then
                        first=false
                    else
                        echo "," >> "$output_file"
                    fi
                    echo "{\"timestamp\":\"${BASH_REMATCH[1]}\",\"level\":\"${BASH_REMATCH[2]}\",\"module\":\"${BASH_REMATCH[3]}\",\"message\":\"${BASH_REMATCH[4]}\"}" >> "$output_file"
                fi
            done < "$log_file"
            echo "]" >> "$output_file"
            ;;
        "csv")
            # 转换为 CSV 格式
            echo "timestamp,level,module,message" > "$output_file"
            while IFS= read -r line; do
                if [[ $line =~ ^\[([^\]]+)\]\ \[([^\]]+)\]\ \[([^\]]+)\]\ (.*)$ ]]; then
                    echo "\"${BASH_REMATCH[1]}\",\"${BASH_REMATCH[2]}\",\"${BASH_REMATCH[3]}\",\"${BASH_REMATCH[4]}\"" >> "$output_file"
                fi
            done < "$log_file"
            ;;
        *)
            log_error "不支持的导出格式: $format"
            return 1
            ;;
    esac
    
    log_info "日志导出完成: $output_file"
}

# 解析命令行参数
COMMAND=""
LOG_FILE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            set_log_level "DEBUG"
            shift
            ;;
        -f|--file)
            LOG_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            export LOG_ARCHIVE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        query|stats|rotate|clean|archive|tail|watch|export)
            COMMAND="$1"
            shift
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                log_error "未知命令: $1"
                show_help
                exit 1
            fi
            ;;
    esac
done

# 执行命令
case "$COMMAND" in
    "query")
        cmd_query "$@"
        ;;
    "stats")
        cmd_stats "$@"
        ;;
    "rotate")
        cmd_rotate "$@"
        ;;
    "clean")
        cmd_clean "$@"
        ;;
    "archive")
        cmd_archive "$@"
        ;;
    "tail")
        cmd_tail "$@"
        ;;
    "watch")
        cmd_watch "$@"
        ;;
    "export")
        cmd_export "$@"
        ;;
    *)
        log_error "请指定一个命令"
        show_help
        exit 1
        ;;
esac