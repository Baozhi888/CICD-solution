#!/bin/bash

# 配置管理库
# 提供配置文件加载、验证和管理功能
# 支持模块化配置和环境覆盖

# 颜色定义
CFG_RED='\033[0;31m'
CFG_GREEN='\033[0;32m'
CFG_YELLOW='\033[1;33m'
CFG_BLUE='\033[0;34m'
CFG_NC='\033[0m' # No Color

# 日志函数
cfg_log_debug() {
    if [ "${CFG_LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        echo -e "${CFG_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [CONFIG DEBUG]${CFG_NC} $1" >&2
    fi
}

cfg_log_info() {
    echo -e "${CFG_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [CONFIG INFO]${CFG_NC} $1" >&2
}

cfg_log_warn() {
    echo -e "${CFG_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [CONFIG WARN]${CFG_NC} $1" >&2
}

cfg_log_error() {
    echo -e "${CFG_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [CONFIG ERROR]${CFG_NC} $1" >&2
}

# 默认配置文件路径
CFG_DEFAULT_CONFIG_FILE="/root/idear/cicd-solution/config/central-config.yaml"
CFG_LOCAL_CONFIG_FILE="./config.yaml"
CFG_ENV_CONFIG_DIR="/root/idear/cicd-solution/config/environment"

# 加载YAML配置文件
# 注意：此函数需要yq工具支持
load_yaml_config() {
    local config_file="$1"
    
    if [ ! -f "$config_file" ]; then
        cfg_log_warn "配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查yq命令是否存在
    if ! command -v yq &> /dev/null; then
        cfg_log_error "缺少yq命令，无法解析YAML配置文件"
        return 1
    fi
    
    # 导出配置为环境变量
    while IFS= read -r line; do
        if [[ $line =~ ^([^:]+):[[:space:]]*(.*)$ ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # 移除引号
            value="${value%\"}"
            value="${value#\"}"
            export "CFG_${key^^}"="$value"
            cfg_log_debug "加载配置项: CFG_${key^^}=$value"
        fi
    done < <(yq eval 'to_entries | .[] | .key + ": " + (.value | tostring)' "$config_file")
    
    cfg_log_info "成功加载配置文件: $config_file"
    return 0
}

# 加载配置文件（支持多种格式）
load_config() {
    local config_file="$1"
    
    if [ -z "$config_file" ]; then
        cfg_log_error "必须指定配置文件路径"
        return 1
    fi
    
    # 根据文件扩展名确定加载方式
    case "${config_file##*.}" in
        yaml|yml)
            load_yaml_config "$config_file"
            ;;
        json)
            load_json_config "$config_file"
            ;;
        *)
            cfg_log_error "不支持的配置文件格式: ${config_file##*.}"
            return 1
            ;;
    esac
}

# 获取配置值
get_config() {
    local key="$1"
    local default_value="$2"
    
    # 优先级：环境变量 > 配置文件 > 默认值
    # 将点号替换为下划线，并将键转换为大写
    local env_key="CFG_$(echo "$key" | tr '[:lower:].' '[:upper:]_')"
    local value="${!env_key:-$default_value}"
    
    # 如果配置文件已加载，从配置文件获取
    if [ -n "${CONFIG_DATA:-}" ] && [ "$value" = "$default_value" ]; then
        # 使用 yq 提取配置值（如果可用）
        if command -v yq >/dev/null 2>&1 && [ -f "${CONFIG_FILE:-}" ]; then
            local config_value=$(yq eval ".${key}" "${CONFIG_FILE:-}" 2>/dev/null)
            if [ "$config_value" != "null" ] && [ -n "$config_value" ]; then
                value="$config_value"
            fi
        fi
    fi
    
    echo "$value"
}

# 设置配置值
set_config() {
    local key="$1"
    local value="$2"
    
    export "CFG_${key^^}"="$value"
    cfg_log_debug "设置配置项: CFG_${key^^}=$value"
}

# 合并配置（环境配置 > 本地配置 > 全局配置）
merge_configs() {
    local global_config="$1"
    local local_config="$2"
    local env_name="${3:-$ENV}"
    
    cfg_log_info "合并配置文件: $global_config -> $local_config (环境: ${env_name:-default})"
    
    # 先加载全局配置
    if [ -f "$global_config" ]; then
        load_config "$global_config"
    fi
    
    # 再加载本地配置（覆盖全局配置）
    if [ -f "$local_config" ]; then
        load_config "$local_config"
    fi
    
    # 最后加载环境特定配置（覆盖所有）
    if [ -n "$env_name" ] && [ -d "$CFG_ENV_CONFIG_DIR" ]; then
        local env_config_file="$CFG_ENV_CONFIG_DIR/${env_name}.yaml"
        if [ -f "$env_config_file" ]; then
            cfg_log_info "加载环境配置: $env_config_file"
            load_config "$env_config_file"
        fi
    fi
    
    cfg_log_info "配置合并完成"
}

# 验证必需配置项
validate_required_configs() {
    local required_configs=("$@")
    local missing_configs=()
    
    for config in "${required_configs[@]}"; do
        local value=$(get_config "$config")
        if [ -z "$value" ]; then
            missing_configs+=("$config")
        fi
    done
    
    if [ ${#missing_configs[@]} -gt 0 ]; then
        cfg_log_error "缺少必需的配置项: ${missing_configs[*]}"
        return 1
    fi
    
    cfg_log_info "必需配置项验证通过"
    return 0
}

# 验证配置值范围
validate_config_range() {
    local key="$1"
    local min_value="$2"
    local max_value="$3"
    
    local value=$(get_config "$key")
    
    if [ -n "$value" ] && [[ $value =~ ^-?[0-9]+([.][0-9]+)?$ ]]; then
        if (( $(echo "$value < $min_value" | bc -l) )) || (( $(echo "$value > $max_value" | bc -l) )); then
            cfg_log_error "配置项 $key 的值 $value 超出范围 [$min_value, $max_value]"
            return 1
        fi
    else
        cfg_log_warn "配置项 $key 的值 $value 不是有效数字"
        return 1
    fi
    
    cfg_log_debug "配置项 $key 的值 $value 在有效范围内"
    return 0
}

# 初始化配置管理器
init_config_manager() {
    cfg_log_info "初始化配置管理器"
    
    # 设置默认日志级别
    export CFG_LOG_LEVEL="${CFG_LOG_LEVEL:-INFO}"
    
    # 合并默认配置文件
    merge_configs "$CFG_DEFAULT_CONFIG_FILE" "$CFG_LOCAL_CONFIG_FILE" "$ENV"
    
    cfg_log_info "配置管理器初始化完成"
}