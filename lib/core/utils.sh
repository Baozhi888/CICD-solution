#!/bin/bash

# 通用工具库
# 提供常用的工具函数

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 检查文件是否存在
file_exists() {
    [ -f "$1" ]
}

# 检查目录是否存在
dir_exists() {
    [ -d "$1" ]
}

# 创建目录（如果不存在）
ensure_dir() {
    local dir="$1"
    if ! dir_exists "$dir"; then
        mkdir -p "$dir"
    fi
}

# 生成随机字符串
random_string() {
    local length=${1:-8}
    cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w "$length" | head -n 1
}

# 获取当前时间戳
timestamp() {
    date +%s
}

# 格式化时间
format_time() {
    date '+%Y-%m-%d %H:%M:%S'
}

# 计算执行时间
time_execution() {
    local start_time=$(timestamp)
    "$@"
    local end_time=$(timestamp)
    local duration=$((end_time - start_time))
    echo "执行时间: ${duration}秒"
}

# 检查URL是否可访问
check_url() {
    local url="$1"
    local timeout=${2:-10}
    
    if command_exists curl; then
        curl -s -f -m "$timeout" "$url" >/dev/null 2>&1
    elif command_exists wget; then
        wget -q -O /dev/null --timeout="$timeout" "$url" >/dev/null 2>&1
    else
        echo "错误: 未找到curl或wget命令" >&2
        return 1
    fi
}

# 下载文件
download_file() {
    local url="$1"
    local output="$2"
    
    if command_exists curl; then
        curl -s -L -o "$output" "$url"
    elif command_exists wget; then
        wget -q -O "$output" "$url"
    else
        echo "错误: 未找到curl或wget命令" >&2
        return 1
    fi
}

# 解压文件
extract_file() {
    local file="$1"
    local dest="$2"
    
    ensure_dir "$dest"
    
    case "$file" in
        *.tar.gz|*.tgz)
            tar -xzf "$file" -C "$dest"
            ;;
        *.tar.bz2)
            tar -xjf "$file" -C "$dest"
            ;;
        *.zip)
            unzip -q "$file" -d "$dest"
            ;;
        *.tar)
            tar -xf "$file" -C "$dest"
            ;;
        *)
            echo "错误: 不支持的文件格式: $file" >&2
            return 1
            ;;
    esac
}

# 获取文件大小
file_size() {
    local file="$1"
    
    if file_exists "$file"; then
        if command_exists stat; then
            stat -c%s "$file"
        elif command_exists wc; then
            wc -c < "$file"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# 检查磁盘空间
check_disk_space() {
    local path="$1"
    local threshold=${2:-90}
    
    local usage=$(df "$path" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [ "$usage" -gt "$threshold" ]; then
        return 1
    else
        return 0
    fi
}

# 字符串处理函数
trim() {
    local var="$*"
    # 删除前导空格
    var="${var#"${var%%[![:space:]]*}"}"
    # 删除尾随空格
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

to_upper() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# 检查字符串是否为空
is_empty() {
    [ -z "$1" ]
}

# 检查字符串是否非空
is_not_empty() {
    [ -n "$1" ]
}

# 错误处理函数（简化版）
handle_error() {
    local error_msg="$1"
    local log_file="${2:-/tmp/cicd-errors.log}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $error_msg" >> "$log_file"
    echo "ERROR: $error_msg" >&2
}