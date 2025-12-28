#!/bin/bash

# =============================================================================
# AI 核心模块
# =============================================================================
# 提供 AI 功能的核心初始化、配置管理和基础设施
# 支持 Claude API 和 OpenAI 兼容 API
# =============================================================================

# 防止重复加载
if [ -n "${_AI_CORE_LOADED:-}" ]; then
    return 0
fi
_AI_CORE_LOADED=1

# 模块版本
AI_MODULE_VERSION="1.0.0"

# 颜色定义
AI_RED='\033[0;31m'
AI_GREEN='\033[0;32m'
AI_YELLOW='\033[1;33m'
AI_BLUE='\033[0;34m'
AI_PURPLE='\033[0;35m'
AI_CYAN='\033[0;36m'
AI_NC='\033[0m'

# AI 配置默认值
AI_ENABLED="${AI_ENABLED:-false}"
AI_PROVIDER="${AI_PROVIDER:-claude}"
AI_LOG_LEVEL="${AI_LOG_LEVEL:-INFO}"

# Claude API 默认值
AI_CLAUDE_API_KEY="${CLAUDE_API_KEY:-}"
AI_CLAUDE_MODEL="${AI_CLAUDE_MODEL:-claude-sonnet-4-20250514}"
AI_CLAUDE_MAX_TOKENS="${AI_CLAUDE_MAX_TOKENS:-4096}"
AI_CLAUDE_BASE_URL="${AI_CLAUDE_BASE_URL:-https://api.anthropic.com}"

# OpenAI API 默认值
AI_OPENAI_API_KEY="${OPENAI_API_KEY:-}"
AI_OPENAI_MODEL="${AI_OPENAI_MODEL:-gpt-4}"
AI_OPENAI_MAX_TOKENS="${AI_OPENAI_MAX_TOKENS:-4096}"
AI_OPENAI_BASE_URL="${AI_OPENAI_BASE_URL:-https://api.openai.com/v1}"

# 缓存配置
AI_CACHE_ENABLED="${AI_CACHE_ENABLED:-true}"
AI_CACHE_TTL="${AI_CACHE_TTL:-3600}"
AI_CACHE_DIR="${AI_CACHE_DIR:-/tmp/aicd-cache}"

# 日志文件
AI_LOG_FILE="${AI_LOG_FILE:-/tmp/aicd-ai.log}"

# =============================================================================
# 日志函数
# =============================================================================

ai_log_debug() {
    if [ "${AI_LOG_LEVEL}" = "DEBUG" ]; then
        echo -e "${AI_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [AI DEBUG]${AI_NC} $1" >&2
        ai_log_to_file "DEBUG" "$1"
    fi
}

ai_log_info() {
    if [ "${AI_LOG_LEVEL}" != "ERROR" ] && [ "${AI_LOG_LEVEL}" != "WARN" ]; then
        echo -e "${AI_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [AI INFO]${AI_NC} $1" >&2
        ai_log_to_file "INFO" "$1"
    fi
}

ai_log_warn() {
    if [ "${AI_LOG_LEVEL}" != "ERROR" ]; then
        echo -e "${AI_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [AI WARN]${AI_NC} $1" >&2
        ai_log_to_file "WARN" "$1"
    fi
}

ai_log_error() {
    echo -e "${AI_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [AI ERROR]${AI_NC} $1" >&2
    ai_log_to_file "ERROR" "$1"
}

ai_log_to_file() {
    local level="$1"
    local message="$2"
    if [ -n "${AI_LOG_FILE}" ]; then
        mkdir -p "$(dirname "${AI_LOG_FILE}")" 2>/dev/null || true
        echo "$(date +'%Y-%m-%d %H:%M:%S') [${level}] ${message}" >> "${AI_LOG_FILE}"
    fi
}

# =============================================================================
# 依赖检查
# =============================================================================

# 检查必需的依赖
ai_check_dependencies() {
    local missing_deps=()

    # 检查 curl
    if ! command -v curl &>/dev/null; then
        missing_deps+=("curl")
    fi

    # 检查 jq
    if ! command -v jq &>/dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        ai_log_error "缺少必需的依赖: ${missing_deps[*]}"
        ai_log_error "请安装: sudo apt install ${missing_deps[*]} 或 brew install ${missing_deps[*]}"
        return 1
    fi

    ai_log_debug "依赖检查通过"
    return 0
}

# =============================================================================
# 配置管理
# =============================================================================

# 加载 AI 配置文件
ai_load_config() {
    local config_file="${1:-}"

    # 自动查找配置文件
    if [ -z "${config_file}" ]; then
        local script_dir
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local project_root="${script_dir}/../.."

        # 查找配置文件的优先级
        local config_paths=(
            "${project_root}/config/ai-config.yaml"
            "${project_root}/ai-config.yaml"
            "./ai-config.yaml"
        )

        for path in "${config_paths[@]}"; do
            if [ -f "${path}" ]; then
                config_file="${path}"
                break
            fi
        done
    fi

    if [ -z "${config_file}" ] || [ ! -f "${config_file}" ]; then
        ai_log_warn "未找到 AI 配置文件，使用默认配置"
        return 0
    fi

    ai_log_info "加载 AI 配置文件: ${config_file}"

    # 使用 yq 解析 YAML (如果可用)
    if command -v yq &>/dev/null; then
        # 解析基本配置
        local enabled
        enabled=$(yq eval '.ai.enabled // "false"' "${config_file}" 2>/dev/null)
        [ "${enabled}" = "true" ] && AI_ENABLED="true"

        local provider
        provider=$(yq eval '.ai.provider // "claude"' "${config_file}" 2>/dev/null)
        [ -n "${provider}" ] && [ "${provider}" != "null" ] && AI_PROVIDER="${provider}"

        # 解析 Claude 配置
        local claude_model
        claude_model=$(yq eval '.ai.api.claude.model // ""' "${config_file}" 2>/dev/null)
        [ -n "${claude_model}" ] && [ "${claude_model}" != "null" ] && AI_CLAUDE_MODEL="${claude_model}"

        local claude_max_tokens
        claude_max_tokens=$(yq eval '.ai.api.claude.max_tokens // ""' "${config_file}" 2>/dev/null)
        [ -n "${claude_max_tokens}" ] && [ "${claude_max_tokens}" != "null" ] && AI_CLAUDE_MAX_TOKENS="${claude_max_tokens}"

        # 解析 OpenAI 配置
        local openai_model
        openai_model=$(yq eval '.ai.api.openai.model // ""' "${config_file}" 2>/dev/null)
        [ -n "${openai_model}" ] && [ "${openai_model}" != "null" ] && AI_OPENAI_MODEL="${openai_model}"

        local openai_base_url
        openai_base_url=$(yq eval '.ai.api.openai.base_url // ""' "${config_file}" 2>/dev/null)
        [ -n "${openai_base_url}" ] && [ "${openai_base_url}" != "null" ] && AI_OPENAI_BASE_URL="${openai_base_url}"

        # 解析缓存配置
        local cache_enabled
        cache_enabled=$(yq eval '.ai.cache.enabled // "true"' "${config_file}" 2>/dev/null)
        [ "${cache_enabled}" = "false" ] && AI_CACHE_ENABLED="false"

        local cache_ttl
        cache_ttl=$(yq eval '.ai.cache.ttl // ""' "${config_file}" 2>/dev/null)
        [ -n "${cache_ttl}" ] && [ "${cache_ttl}" != "null" ] && AI_CACHE_TTL="${cache_ttl}"

        ai_log_debug "配置解析完成: provider=${AI_PROVIDER}, enabled=${AI_ENABLED}"
    else
        ai_log_warn "未安装 yq，无法解析 YAML 配置"
    fi

    return 0
}

# 获取 AI 配置值
ai_get_config() {
    local key="$1"
    local default_value="${2:-}"

    case "${key}" in
        "enabled") echo "${AI_ENABLED}" ;;
        "provider") echo "${AI_PROVIDER}" ;;
        "log_level") echo "${AI_LOG_LEVEL}" ;;
        "claude.api_key") echo "${AI_CLAUDE_API_KEY}" ;;
        "claude.model") echo "${AI_CLAUDE_MODEL}" ;;
        "claude.max_tokens") echo "${AI_CLAUDE_MAX_TOKENS}" ;;
        "claude.base_url") echo "${AI_CLAUDE_BASE_URL}" ;;
        "openai.api_key") echo "${AI_OPENAI_API_KEY}" ;;
        "openai.model") echo "${AI_OPENAI_MODEL}" ;;
        "openai.max_tokens") echo "${AI_OPENAI_MAX_TOKENS}" ;;
        "openai.base_url") echo "${AI_OPENAI_BASE_URL}" ;;
        "cache.enabled") echo "${AI_CACHE_ENABLED}" ;;
        "cache.ttl") echo "${AI_CACHE_TTL}" ;;
        "cache.dir") echo "${AI_CACHE_DIR}" ;;
        *) echo "${default_value}" ;;
    esac
}

# 设置 AI 配置值
ai_set_config() {
    local key="$1"
    local value="$2"

    case "${key}" in
        "enabled") AI_ENABLED="${value}" ;;
        "provider") AI_PROVIDER="${value}" ;;
        "log_level") AI_LOG_LEVEL="${value}" ;;
        "claude.api_key") AI_CLAUDE_API_KEY="${value}" ;;
        "claude.model") AI_CLAUDE_MODEL="${value}" ;;
        "claude.max_tokens") AI_CLAUDE_MAX_TOKENS="${value}" ;;
        "openai.api_key") AI_OPENAI_API_KEY="${value}" ;;
        "openai.model") AI_OPENAI_MODEL="${value}" ;;
        "openai.max_tokens") AI_OPENAI_MAX_TOKENS="${value}" ;;
        "openai.base_url") AI_OPENAI_BASE_URL="${value}" ;;
        "cache.enabled") AI_CACHE_ENABLED="${value}" ;;
        "cache.ttl") AI_CACHE_TTL="${value}" ;;
        *)
            ai_log_warn "未知的配置项: ${key}"
            return 1
            ;;
    esac

    ai_log_debug "设置配置: ${key}=${value}"
    return 0
}

# =============================================================================
# 核心功能
# =============================================================================

# 检查 AI 功能是否启用
ai_is_enabled() {
    [ "${AI_ENABLED}" = "true" ]
}

# 验证 API 密钥
ai_validate_api_key() {
    local provider="${1:-${AI_PROVIDER}}"

    case "${provider}" in
        claude)
            if [ -z "${AI_CLAUDE_API_KEY}" ]; then
                ai_log_error "未设置 Claude API 密钥 (CLAUDE_API_KEY)"
                return 1
            fi
            ai_log_debug "Claude API 密钥已配置"
            ;;
        openai)
            if [ -z "${AI_OPENAI_API_KEY}" ]; then
                ai_log_error "未设置 OpenAI API 密钥 (OPENAI_API_KEY)"
                return 1
            fi
            ai_log_debug "OpenAI API 密钥已配置"
            ;;
        *)
            ai_log_error "不支持的 AI 提供商: ${provider}"
            return 1
            ;;
    esac

    return 0
}

# 获取当前提供商信息
ai_get_provider_info() {
    local provider="${AI_PROVIDER}"
    local model api_key base_url

    case "${provider}" in
        claude)
            model="${AI_CLAUDE_MODEL}"
            api_key="${AI_CLAUDE_API_KEY:0:10}..."
            base_url="${AI_CLAUDE_BASE_URL}"
            ;;
        openai)
            model="${AI_OPENAI_MODEL}"
            api_key="${AI_OPENAI_API_KEY:0:10}..."
            base_url="${AI_OPENAI_BASE_URL}"
            ;;
    esac

    echo "Provider: ${provider}"
    echo "Model: ${model}"
    echo "API Key: ${api_key}"
    echo "Base URL: ${base_url}"
}

# =============================================================================
# 缓存管理
# =============================================================================

# 初始化缓存目录
ai_init_cache() {
    if [ "${AI_CACHE_ENABLED}" = "true" ]; then
        mkdir -p "${AI_CACHE_DIR}" 2>/dev/null
        ai_log_debug "缓存目录初始化: ${AI_CACHE_DIR}"
    fi
}

# 获取缓存
ai_cache_get() {
    local cache_key="$1"
    local cache_file="${AI_CACHE_DIR}/${cache_key}.cache"

    if [ "${AI_CACHE_ENABLED}" != "true" ]; then
        return 1
    fi

    if [ ! -f "${cache_file}" ]; then
        return 1
    fi

    # 检查缓存是否过期
    local cache_time
    cache_time=$(stat -c %Y "${cache_file}" 2>/dev/null || stat -f %m "${cache_file}" 2>/dev/null)
    local current_time
    current_time=$(date +%s)
    local age=$((current_time - cache_time))

    if [ "${age}" -gt "${AI_CACHE_TTL}" ]; then
        rm -f "${cache_file}"
        return 1
    fi

    cat "${cache_file}"
    return 0
}

# 设置缓存
ai_cache_set() {
    local cache_key="$1"
    local cache_value="$2"
    local cache_file="${AI_CACHE_DIR}/${cache_key}.cache"

    if [ "${AI_CACHE_ENABLED}" != "true" ]; then
        return 0
    fi

    mkdir -p "${AI_CACHE_DIR}" 2>/dev/null
    echo "${cache_value}" > "${cache_file}"
    ai_log_debug "缓存已设置: ${cache_key}"
    return 0
}

# 清理过期缓存
ai_cache_cleanup() {
    if [ "${AI_CACHE_ENABLED}" != "true" ] || [ ! -d "${AI_CACHE_DIR}" ]; then
        return 0
    fi

    local current_time
    current_time=$(date +%s)
    local cleaned=0

    for cache_file in "${AI_CACHE_DIR}"/*.cache; do
        [ -f "${cache_file}" ] || continue

        local cache_time
        cache_time=$(stat -c %Y "${cache_file}" 2>/dev/null || stat -f %m "${cache_file}" 2>/dev/null)
        local age=$((current_time - cache_time))

        if [ "${age}" -gt "${AI_CACHE_TTL}" ]; then
            rm -f "${cache_file}"
            ((cleaned++))
        fi
    done

    ai_log_debug "清理过期缓存: ${cleaned} 个文件"
    return 0
}

# 清空所有缓存
ai_cache_clear() {
    if [ -d "${AI_CACHE_DIR}" ]; then
        rm -rf "${AI_CACHE_DIR}"/*.cache
        ai_log_info "已清空所有缓存"
    fi
}

# =============================================================================
# 初始化
# =============================================================================

# 初始化 AI 模块
ai_init() {
    local config_file="${1:-}"

    ai_log_info "初始化 AI 模块 v${AI_MODULE_VERSION}"

    # 检查依赖
    if ! ai_check_dependencies; then
        return 1
    fi

    # 加载配置
    ai_load_config "${config_file}"

    # 初始化缓存
    ai_init_cache

    # 验证配置
    if ai_is_enabled; then
        if ! ai_validate_api_key; then
            ai_log_warn "API 密钥验证失败，AI 功能可能无法正常使用"
        fi
    else
        ai_log_info "AI 功能已禁用"
    fi

    ai_log_info "AI 模块初始化完成"
    return 0
}

# 显示 AI 模块状态
ai_status() {
    echo "=========================================="
    echo "AI 模块状态"
    echo "=========================================="
    echo "版本: ${AI_MODULE_VERSION}"
    echo "启用状态: ${AI_ENABLED}"
    echo "提供商: ${AI_PROVIDER}"
    echo "日志级别: ${AI_LOG_LEVEL}"
    echo ""
    echo "--- Claude API ---"
    echo "模型: ${AI_CLAUDE_MODEL}"
    echo "最大 Token: ${AI_CLAUDE_MAX_TOKENS}"
    echo "API Key: ${AI_CLAUDE_API_KEY:+已配置}"
    echo ""
    echo "--- OpenAI API ---"
    echo "模型: ${AI_OPENAI_MODEL}"
    echo "最大 Token: ${AI_OPENAI_MAX_TOKENS}"
    echo "Base URL: ${AI_OPENAI_BASE_URL}"
    echo "API Key: ${AI_OPENAI_API_KEY:+已配置}"
    echo ""
    echo "--- 缓存 ---"
    echo "启用: ${AI_CACHE_ENABLED}"
    echo "TTL: ${AI_CACHE_TTL}s"
    echo "目录: ${AI_CACHE_DIR}"
    echo "=========================================="
}
