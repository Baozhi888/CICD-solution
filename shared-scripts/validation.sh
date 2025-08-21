#!/bin/bash

# 参数验证库
# 提供参数验证功能

# 验证是否为数字
is_number() {
    local value="$1"
    if [[ $value =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证是否为正整数
is_positive_integer() {
    local value="$1"
    if [[ $value =~ ^[0-9]+$ ]] && [ "$value" -gt 0 ]; then
        return 0
    else
        return 1
    fi
}

# 验证是否为邮箱地址
is_email() {
    local email="$1"
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证是否为URL
is_url() {
    local url="$1"
    if [[ $url =~ ^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(/.*)?$ ]]; then
        return 0
    else
        return 1
    fi
}

# 验证是否为IP地址
is_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        local octets=(${ip//./ })
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# 验证是否为日期格式 (YYYY-MM-DD)
is_date() {
    local date_str="$1"
    if [[ $date_str =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        local year=${date_str:0:4}
        local month=${date_str:5:2}
        local day=${date_str:8:2}
        
        # 检查月份范围
        if [ "$month" -ge 1 ] && [ "$month" -le 12 ]; then
            # 检查日期范围（简化检查，不考虑闰年）
            if [ "$day" -ge 1 ] && [ "$day" -le 31 ]; then
                return 0
            fi
        fi
    fi
    return 1
}

# 验证是否为时间格式 (HH:MM:SS)
is_time() {
    local time_str="$1"
    if [[ $time_str =~ ^[0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]; then
        local hour=${time_str:0:2}
        local minute=${time_str:3:2}
        local second=${time_str:6:2}
        
        # 检查小时范围
        if [ "$hour" -ge 0 ] && [ "$hour" -le 23 ]; then
            # 检查分钟和秒范围
            if [ "$minute" -ge 0 ] && [ "$minute" -le 59 ] && [ "$second" -ge 0 ] && [ "$second" -le 59 ]; then
                return 0
            fi
        fi
    fi
    return 1
}

# 验证是否为布尔值
is_boolean() {
    local value="$1"
    case "$value" in
        true|false|TRUE|FALSE|True|False|1|0)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# 验证是否为非空字符串
is_non_empty() {
    local value="$1"
    if [ -n "$value" ]; then
        return 0
    else
        return 1
    fi
}

# 验证文件是否存在且可读
is_readable_file() {
    local file="$1"
    if [ -f "$file" ] && [ -r "$file" ]; then
        return 0
    else
        return 1
    fi
}

# 验证目录是否存在且可写
is_writable_dir() {
    local dir="$1"
    if [ -d "$dir" ] && [ -w "$dir" ]; then
        return 0
    else
        return 1
    fi
}

# 验证端口号范围 (1-65535)
is_port() {
    local port="$1"
    if is_positive_integer "$port" && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]; then
        return 0
    else
        return 1
    fi
}