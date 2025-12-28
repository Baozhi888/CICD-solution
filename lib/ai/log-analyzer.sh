#!/bin/bash

# =============================================================================
# AI 日志分析器
# =============================================================================
# 使用 AI 分析日志文件，识别错误模式，提供解决建议
# =============================================================================

# 防止重复加载
if [ -n "${_AI_LOG_ANALYZER_LOADED:-}" ]; then
    return 0
fi
_AI_LOG_ANALYZER_LOADED=1

# 加载依赖模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ai-core.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/api-client.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/prompt-templates.sh" 2>/dev/null || true

# 日志分析配置
LOG_ANALYZER_CONTEXT_LINES="${LOG_ANALYZER_CONTEXT_LINES:-50}"
LOG_ANALYZER_MAX_LOG_SIZE="${LOG_ANALYZER_MAX_LOG_SIZE:-50000}"  # 最大分析的日志大小（字符）

# =============================================================================
# 日志读取和预处理
# =============================================================================

# 读取日志文件
_log_read_file() {
    local log_file="$1"
    local lines="${2:-${LOG_ANALYZER_CONTEXT_LINES}}"

    if [ ! -f "${log_file}" ]; then
        ai_log_error "日志文件不存在: ${log_file}"
        return 1
    fi

    # 读取最后 N 行
    tail -n "${lines}" "${log_file}" 2>/dev/null
}

# 读取日志目录
_log_read_directory() {
    local log_dir="$1"
    local pattern="${2:-*.log}"
    local lines="${3:-${LOG_ANALYZER_CONTEXT_LINES}}"

    if [ ! -d "${log_dir}" ]; then
        ai_log_error "日志目录不存在: ${log_dir}"
        return 1
    fi

    local combined_logs=""
    while IFS= read -r -d '' log_file; do
        combined_logs+="=== ${log_file} ===\n"
        combined_logs+=$(_log_read_file "${log_file}" "${lines}")
        combined_logs+="\n\n"
    done < <(find "${log_dir}" -name "${pattern}" -type f -print0 2>/dev/null | head -z -n 10)

    echo -e "${combined_logs}"
}

# 提取错误日志
_log_extract_errors() {
    local log_content="$1"
    local error_patterns="${2:-ERROR|FATAL|CRITICAL|Exception|Traceback|panic:|FAIL}"

    echo "${log_content}" | grep -E -i "${error_patterns}" | tail -n "${LOG_ANALYZER_CONTEXT_LINES}"
}

# 截断日志以符合大小限制
_log_truncate() {
    local log_content="$1"
    local max_size="${2:-${LOG_ANALYZER_MAX_LOG_SIZE}}"

    if [ ${#log_content} -gt ${max_size} ]; then
        ai_log_warn "日志内容过长，已截断至 ${max_size} 字符"
        echo "${log_content:0:${max_size}}

... (日志已截断，显示前 ${max_size} 字符)"
    else
        echo "${log_content}"
    fi
}

# 脱敏处理
_log_redact_sensitive() {
    local log_content="$1"

    # 脱敏常见敏感信息
    echo "${log_content}" | sed -E \
        -e 's/(password|passwd|pwd)[[:space:]]*[:=][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi' \
        -e 's/(api[_-]?key|apikey)[[:space:]]*[:=][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi' \
        -e 's/(secret|token)[[:space:]]*[:=][[:space:]]*[^[:space:]]*/\1=***REDACTED***/gi' \
        -e 's/(bearer|authorization)[[:space:]]+[^[:space:]]*/\1 ***REDACTED***/gi' \
        -e 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/***EMAIL***/g'
}

# =============================================================================
# 日志分析功能
# =============================================================================

# 分析日志文件
# 用法: ai_analyze_logs <log_file_or_dir> [context]
ai_analyze_logs() {
    local log_source="$1"
    local context="${2:-}"

    if [ -z "${log_source}" ]; then
        ai_log_error "请指定日志文件或目录"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用，请在配置中设置 ai.enabled: true"
        return 1
    fi

    ai_log_info "开始分析日志: ${log_source}"

    # 读取日志内容
    local log_content
    if [ -d "${log_source}" ]; then
        log_content=$(_log_read_directory "${log_source}")
    else
        log_content=$(_log_read_file "${log_source}")
    fi

    if [ -z "${log_content}" ]; then
        ai_log_warn "日志内容为空"
        return 0
    fi

    # 预处理
    log_content=$(_log_truncate "${log_content}")
    log_content=$(_log_redact_sensitive "${log_content}")

    # 生成提示词
    local system_prompt
    system_prompt=$(ai_get_system_prompt "log_analyzer")
    local user_prompt
    user_prompt=$(ai_prompt_log_analysis "${log_content}" "${context}")

    # 调用 AI API
    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        ai_log_error "日志分析失败"
        return 1
    fi
}

# 检测错误模式
# 用法: ai_detect_errors <log_file_or_content>
ai_detect_errors() {
    local input="$1"
    local log_content

    # 判断是文件还是内容
    if [ -f "${input}" ]; then
        log_content=$(_log_read_file "${input}")
    else
        log_content="${input}"
    fi

    if [ -z "${log_content}" ]; then
        ai_log_warn "没有找到错误日志"
        return 0
    fi

    # 提取错误
    local errors
    errors=$(_log_extract_errors "${log_content}")

    if [ -z "${errors}" ]; then
        ai_log_info "没有检测到错误"
        echo "没有检测到错误日志"
        return 0
    fi

    if ! ai_is_enabled; then
        # 如果 AI 未启用，只返回错误摘要
        echo "=== 检测到的错误 ==="
        echo "${errors}"
        return 0
    fi

    # 预处理
    errors=$(_log_truncate "${errors}")
    errors=$(_log_redact_sensitive "${errors}")

    # 调用 AI 分析
    local system_prompt
    system_prompt=$(ai_get_system_prompt "log_analyzer")
    local user_prompt
    user_prompt=$(ai_prompt_error_diagnosis "${errors}")

    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        # 如果 AI 调用失败，返回原始错误
        echo "=== 检测到的错误 (AI 分析不可用) ==="
        echo "${errors}"
        return 1
    fi
}

# 建议修复方案
# 用法: ai_suggest_fixes <error_message> [stack_trace] [context]
ai_suggest_fixes() {
    local error_message="$1"
    local stack_trace="${2:-}"
    local context="${3:-}"

    if [ -z "${error_message}" ]; then
        ai_log_error "请提供错误信息"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "生成修复建议..."

    # 脱敏处理
    error_message=$(_log_redact_sensitive "${error_message}")
    stack_trace=$(_log_redact_sensitive "${stack_trace}")

    # 生成提示词
    local system_prompt
    system_prompt=$(ai_get_system_prompt "log_analyzer")
    local user_prompt
    user_prompt=$(ai_prompt_error_diagnosis "${error_message}" "${stack_trace}" "${context}")

    # 调用 AI API
    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        ai_log_error "生成修复建议失败"
        return 1
    fi
}

# 生成日志摘要
# 用法: ai_summarize_logs <log_file_or_dir>
ai_summarize_logs() {
    local log_source="$1"

    if [ -z "${log_source}" ]; then
        ai_log_error "请指定日志文件或目录"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "生成日志摘要: ${log_source}"

    # 读取日志内容
    local log_content
    if [ -d "${log_source}" ]; then
        log_content=$(_log_read_directory "${log_source}")
    else
        log_content=$(_log_read_file "${log_source}")
    fi

    if [ -z "${log_content}" ]; then
        ai_log_warn "日志内容为空"
        return 0
    fi

    # 预处理
    log_content=$(_log_truncate "${log_content}")
    log_content=$(_log_redact_sensitive "${log_content}")

    # 生成提示词
    local system_prompt
    system_prompt=$(ai_get_system_prompt "log_analyzer")
    local user_prompt
    user_prompt="请为以下日志生成简洁的摘要，包括：
1. 主要事件和活动
2. 错误和警告统计
3. 关键时间点
4. 需要关注的问题

日志内容：
\`\`\`
${log_content}
\`\`\`"

    # 调用 AI API
    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        ai_log_error "生成日志摘要失败"
        return 1
    fi
}

# =============================================================================
# 实时日志监控
# =============================================================================

# 监控日志文件
# 用法: ai_monitor_logs <log_file> [callback]
ai_monitor_logs() {
    local log_file="$1"
    local callback="${2:-_log_default_callback}"
    local error_patterns="${3:-ERROR|FATAL|CRITICAL|Exception}"

    if [ ! -f "${log_file}" ]; then
        ai_log_error "日志文件不存在: ${log_file}"
        return 1
    fi

    ai_log_info "开始监控日志: ${log_file}"
    ai_log_info "按 Ctrl+C 停止监控"

    # 使用 tail -f 监控日志
    tail -f "${log_file}" 2>/dev/null | while IFS= read -r line; do
        # 检查是否匹配错误模式
        if echo "${line}" | grep -qE -i "${error_patterns}"; then
            ai_log_warn "检测到错误: ${line:0:100}..."
            ${callback} "${line}"
        fi
    done
}

# 默认回调函数
_log_default_callback() {
    local error_line="$1"
    echo "[监控] 错误: ${error_line}"
}

# =============================================================================
# 日志统计分析
# =============================================================================

# 生成日志统计报告
# 用法: ai_log_stats <log_file_or_dir>
ai_log_stats() {
    local log_source="$1"

    if [ -z "${log_source}" ]; then
        ai_log_error "请指定日志文件或目录"
        return 1
    fi

    local log_content
    if [ -d "${log_source}" ]; then
        log_content=$(_log_read_directory "${log_source}" "*.log" 1000)
    else
        log_content=$(_log_read_file "${log_source}" 1000)
    fi

    if [ -z "${log_content}" ]; then
        ai_log_warn "日志内容为空"
        return 0
    fi

    # 本地统计
    local total_lines error_count warn_count info_count
    total_lines=$(echo "${log_content}" | wc -l)
    error_count=$(echo "${log_content}" | grep -c -E -i 'ERROR|FATAL|CRITICAL' || echo 0)
    warn_count=$(echo "${log_content}" | grep -c -E -i 'WARN|WARNING' || echo 0)
    info_count=$(echo "${log_content}" | grep -c -E -i 'INFO' || echo 0)

    echo "=== 日志统计报告 ==="
    echo "日志来源: ${log_source}"
    echo "总行数: ${total_lines}"
    echo ""
    echo "--- 日志级别分布 ---"
    echo "ERROR/FATAL/CRITICAL: ${error_count}"
    echo "WARN/WARNING: ${warn_count}"
    echo "INFO: ${info_count}"
    echo ""

    # 如果 AI 启用，生成更详细的分析
    if ai_is_enabled; then
        echo "--- AI 深度分析 ---"
        ai_summarize_logs "${log_source}"
    fi
}
