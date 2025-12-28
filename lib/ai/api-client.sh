#!/bin/bash

# =============================================================================
# AI API 客户端
# =============================================================================
# 提供 Claude 和 OpenAI API 的统一调用接口
# 支持流式响应和重试机制
# =============================================================================

# 防止重复加载
if [ -n "${_AI_API_CLIENT_LOADED:-}" ]; then
    return 0
fi
_AI_API_CLIENT_LOADED=1

# 加载核心模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ai-core.sh" 2>/dev/null || true

# API 请求配置
AI_API_TIMEOUT="${AI_API_TIMEOUT:-60}"
AI_API_RETRY_COUNT="${AI_API_RETRY_COUNT:-3}"
AI_API_RETRY_DELAY="${AI_API_RETRY_DELAY:-2}"

# =============================================================================
# Claude API
# =============================================================================

# 调用 Claude API
# 参数: $1 - 系统提示词, $2 - 用户消息
# 返回: API 响应内容
ai_api_claude() {
    local system_prompt="${1:-You are a helpful assistant.}"
    local user_message="$2"
    local model="${3:-${AI_CLAUDE_MODEL}}"
    local max_tokens="${4:-${AI_CLAUDE_MAX_TOKENS}}"

    if [ -z "${user_message}" ]; then
        ai_log_error "用户消息不能为空"
        return 1
    fi

    if [ -z "${AI_CLAUDE_API_KEY}" ]; then
        ai_log_error "未设置 Claude API 密钥"
        return 1
    fi

    ai_log_debug "调用 Claude API: model=${model}, max_tokens=${max_tokens}"

    # 构建请求 JSON
    local request_body
    request_body=$(jq -n \
        --arg model "${model}" \
        --argjson max_tokens "${max_tokens}" \
        --arg system "${system_prompt}" \
        --arg content "${user_message}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $content
                }
            ]
        }')

    # 发送请求
    local response
    local http_code
    local retry=0

    while [ ${retry} -lt ${AI_API_RETRY_COUNT} ]; do
        response=$(curl -s -w "\n%{http_code}" \
            --max-time "${AI_API_TIMEOUT}" \
            -X POST "${AI_CLAUDE_BASE_URL}/v1/messages" \
            -H "Content-Type: application/json" \
            -H "x-api-key: ${AI_CLAUDE_API_KEY}" \
            -H "anthropic-version: 2023-06-01" \
            -d "${request_body}" 2>/dev/null)

        http_code=$(echo "${response}" | tail -1)
        response=$(echo "${response}" | sed '$d')

        if [ "${http_code}" = "200" ]; then
            # 提取响应内容
            local content
            content=$(echo "${response}" | jq -r '.content[0].text // empty' 2>/dev/null)

            if [ -n "${content}" ]; then
                ai_log_debug "Claude API 调用成功"
                echo "${content}"
                return 0
            else
                ai_log_error "无法解析 Claude API 响应"
                echo "${response}"
                return 1
            fi
        elif [ "${http_code}" = "429" ]; then
            ai_log_warn "Claude API 速率限制，等待重试 (${retry}/${AI_API_RETRY_COUNT})"
            sleep "${AI_API_RETRY_DELAY}"
            ((retry++))
        elif [ "${http_code}" = "500" ] || [ "${http_code}" = "502" ] || [ "${http_code}" = "503" ]; then
            ai_log_warn "Claude API 服务器错误 (${http_code})，等待重试"
            sleep "${AI_API_RETRY_DELAY}"
            ((retry++))
        else
            local error_msg
            error_msg=$(echo "${response}" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
            ai_log_error "Claude API 错误 (${http_code}): ${error_msg}"
            return 1
        fi
    done

    ai_log_error "Claude API 调用失败，已达到最大重试次数"
    return 1
}

# =============================================================================
# OpenAI 兼容 API
# =============================================================================

# 调用 OpenAI 兼容 API
# 参数: $1 - 系统提示词, $2 - 用户消息
# 返回: API 响应内容
ai_api_openai() {
    local system_prompt="${1:-You are a helpful assistant.}"
    local user_message="$2"
    local model="${3:-${AI_OPENAI_MODEL}}"
    local max_tokens="${4:-${AI_OPENAI_MAX_TOKENS}}"
    local base_url="${5:-${AI_OPENAI_BASE_URL}}"

    if [ -z "${user_message}" ]; then
        ai_log_error "用户消息不能为空"
        return 1
    fi

    if [ -z "${AI_OPENAI_API_KEY}" ]; then
        ai_log_error "未设置 OpenAI API 密钥"
        return 1
    fi

    ai_log_debug "调用 OpenAI API: model=${model}, base_url=${base_url}"

    # 构建请求 JSON
    local request_body
    request_body=$(jq -n \
        --arg model "${model}" \
        --argjson max_tokens "${max_tokens}" \
        --arg system "${system_prompt}" \
        --arg content "${user_message}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            messages: [
                {
                    role: "system",
                    content: $system
                },
                {
                    role: "user",
                    content: $content
                }
            ]
        }')

    # 发送请求
    local response
    local http_code
    local retry=0

    while [ ${retry} -lt ${AI_API_RETRY_COUNT} ]; do
        response=$(curl -s -w "\n%{http_code}" \
            --max-time "${AI_API_TIMEOUT}" \
            -X POST "${base_url}/chat/completions" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${AI_OPENAI_API_KEY}" \
            -d "${request_body}" 2>/dev/null)

        http_code=$(echo "${response}" | tail -1)
        response=$(echo "${response}" | sed '$d')

        if [ "${http_code}" = "200" ]; then
            # 提取响应内容
            local content
            content=$(echo "${response}" | jq -r '.choices[0].message.content // empty' 2>/dev/null)

            if [ -n "${content}" ]; then
                ai_log_debug "OpenAI API 调用成功"
                echo "${content}"
                return 0
            else
                ai_log_error "无法解析 OpenAI API 响应"
                echo "${response}"
                return 1
            fi
        elif [ "${http_code}" = "429" ]; then
            ai_log_warn "OpenAI API 速率限制，等待重试 (${retry}/${AI_API_RETRY_COUNT})"
            sleep "${AI_API_RETRY_DELAY}"
            ((retry++))
        elif [ "${http_code}" = "500" ] || [ "${http_code}" = "502" ] || [ "${http_code}" = "503" ]; then
            ai_log_warn "OpenAI API 服务器错误 (${http_code})，等待重试"
            sleep "${AI_API_RETRY_DELAY}"
            ((retry++))
        else
            local error_msg
            error_msg=$(echo "${response}" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
            ai_log_error "OpenAI API 错误 (${http_code}): ${error_msg}"
            return 1
        fi
    done

    ai_log_error "OpenAI API 调用失败，已达到最大重试次数"
    return 1
}

# =============================================================================
# 统一 API 调用接口
# =============================================================================

# 通用 API 调用 (自动选择提供商)
# 参数: $1 - 系统提示词, $2 - 用户消息, $3 - 可选提供商
# 返回: API 响应内容
ai_api_call() {
    local system_prompt="${1:-You are a helpful assistant.}"
    local user_message="$2"
    local provider="${3:-${AI_PROVIDER}}"

    if [ -z "${user_message}" ]; then
        ai_log_error "用户消息不能为空"
        return 1
    fi

    # 检查缓存
    if [ "${AI_CACHE_ENABLED}" = "true" ]; then
        local cache_key
        cache_key=$(echo "${provider}:${system_prompt}:${user_message}" | md5sum | cut -d' ' -f1)
        local cached_response
        if cached_response=$(ai_cache_get "${cache_key}"); then
            ai_log_debug "使用缓存响应"
            echo "${cached_response}"
            return 0
        fi
    fi

    # 调用相应的 API
    local response
    case "${provider}" in
        claude)
            response=$(ai_api_claude "${system_prompt}" "${user_message}")
            ;;
        openai)
            response=$(ai_api_openai "${system_prompt}" "${user_message}")
            ;;
        *)
            ai_log_error "不支持的 AI 提供商: ${provider}"
            return 1
            ;;
    esac

    local result=$?

    # 缓存响应
    if [ ${result} -eq 0 ] && [ "${AI_CACHE_ENABLED}" = "true" ]; then
        ai_cache_set "${cache_key}" "${response}"
    fi

    echo "${response}"
    return ${result}
}

# 简单的单次对话调用
# 参数: $1 - 用户消息
# 返回: API 响应内容
ai_ask() {
    local message="$1"
    ai_api_call "You are a helpful assistant specializing in CI/CD, DevOps, and shell scripting." "${message}"
}

# =============================================================================
# 流式响应支持
# =============================================================================

# Claude API 流式调用
ai_api_claude_stream() {
    local system_prompt="${1:-You are a helpful assistant.}"
    local user_message="$2"
    local callback="${3:-echo}"  # 回调函数，处理每个数据块
    local model="${4:-${AI_CLAUDE_MODEL}}"
    local max_tokens="${5:-${AI_CLAUDE_MAX_TOKENS}}"

    if [ -z "${user_message}" ]; then
        ai_log_error "用户消息不能为空"
        return 1
    fi

    if [ -z "${AI_CLAUDE_API_KEY}" ]; then
        ai_log_error "未设置 Claude API 密钥"
        return 1
    fi

    ai_log_debug "调用 Claude API (流式): model=${model}"

    # 构建请求 JSON
    local request_body
    request_body=$(jq -n \
        --arg model "${model}" \
        --argjson max_tokens "${max_tokens}" \
        --arg system "${system_prompt}" \
        --arg content "${user_message}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            stream: true,
            system: $system,
            messages: [
                {
                    role: "user",
                    content: $content
                }
            ]
        }')

    # 发送流式请求
    curl -sN \
        --max-time "${AI_API_TIMEOUT}" \
        -X POST "${AI_CLAUDE_BASE_URL}/v1/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: ${AI_CLAUDE_API_KEY}" \
        -H "anthropic-version: 2023-06-01" \
        -d "${request_body}" 2>/dev/null | while IFS= read -r line; do
            # 解析 SSE 数据
            if [[ "${line}" == data:* ]]; then
                local data="${line#data: }"
                if [ "${data}" != "[DONE]" ]; then
                    local text
                    text=$(echo "${data}" | jq -r '.delta.text // empty' 2>/dev/null)
                    if [ -n "${text}" ]; then
                        ${callback} "${text}"
                    fi
                fi
            fi
        done
}

# OpenAI API 流式调用
ai_api_openai_stream() {
    local system_prompt="${1:-You are a helpful assistant.}"
    local user_message="$2"
    local callback="${3:-echo}"
    local model="${4:-${AI_OPENAI_MODEL}}"
    local max_tokens="${5:-${AI_OPENAI_MAX_TOKENS}}"
    local base_url="${6:-${AI_OPENAI_BASE_URL}}"

    if [ -z "${user_message}" ]; then
        ai_log_error "用户消息不能为空"
        return 1
    fi

    if [ -z "${AI_OPENAI_API_KEY}" ]; then
        ai_log_error "未设置 OpenAI API 密钥"
        return 1
    fi

    ai_log_debug "调用 OpenAI API (流式): model=${model}"

    # 构建请求 JSON
    local request_body
    request_body=$(jq -n \
        --arg model "${model}" \
        --argjson max_tokens "${max_tokens}" \
        --arg system "${system_prompt}" \
        --arg content "${user_message}" \
        '{
            model: $model,
            max_tokens: $max_tokens,
            stream: true,
            messages: [
                {
                    role: "system",
                    content: $system
                },
                {
                    role: "user",
                    content: $content
                }
            ]
        }')

    # 发送流式请求
    curl -sN \
        --max-time "${AI_API_TIMEOUT}" \
        -X POST "${base_url}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${AI_OPENAI_API_KEY}" \
        -d "${request_body}" 2>/dev/null | while IFS= read -r line; do
            if [[ "${line}" == data:* ]]; then
                local data="${line#data: }"
                if [ "${data}" != "[DONE]" ]; then
                    local text
                    text=$(echo "${data}" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)
                    if [ -n "${text}" ]; then
                        ${callback} "${text}"
                    fi
                fi
            fi
        done
}

# =============================================================================
# 工具函数
# =============================================================================

# 估算 Token 数量 (粗略估计)
ai_estimate_tokens() {
    local text="$1"
    # 粗略估计: 英文约 4 字符/token, 中文约 1.5 字符/token
    local char_count=${#text}
    local token_estimate=$((char_count / 3))
    echo "${token_estimate}"
}

# 检查消息是否超过 Token 限制
ai_check_token_limit() {
    local message="$1"
    local max_tokens="${2:-${AI_CLAUDE_MAX_TOKENS}}"

    local estimated_tokens
    estimated_tokens=$(ai_estimate_tokens "${message}")

    if [ "${estimated_tokens}" -gt "${max_tokens}" ]; then
        ai_log_warn "消息可能超过 Token 限制: 估计 ${estimated_tokens} tokens > ${max_tokens}"
        return 1
    fi

    return 0
}

# 截断消息以符合 Token 限制
ai_truncate_message() {
    local message="$1"
    local max_tokens="${2:-${AI_CLAUDE_MAX_TOKENS}}"

    # 粗略估计每个 token 约 3 个字符
    local max_chars=$((max_tokens * 3))

    if [ ${#message} -gt ${max_chars} ]; then
        ai_log_warn "消息已截断以符合 Token 限制"
        echo "${message:0:${max_chars}}..."
    else
        echo "${message}"
    fi
}

# =============================================================================
# API 测试
# =============================================================================

# 测试 API 连接
ai_api_test() {
    local provider="${1:-${AI_PROVIDER}}"

    ai_log_info "测试 ${provider} API 连接..."

    local test_message="Say 'Hello' in one word."
    local response

    case "${provider}" in
        claude)
            response=$(ai_api_claude "You are a test bot." "${test_message}" "" "50")
            ;;
        openai)
            response=$(ai_api_openai "You are a test bot." "${test_message}" "" "50")
            ;;
        *)
            ai_log_error "不支持的提供商: ${provider}"
            return 1
            ;;
    esac

    if [ $? -eq 0 ] && [ -n "${response}" ]; then
        ai_log_info "API 测试成功: ${response}"
        return 0
    else
        ai_log_error "API 测试失败"
        return 1
    fi
}
