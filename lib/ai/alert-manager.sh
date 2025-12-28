#!/bin/bash

# =============================================================================
# AI 智能告警管理器
# =============================================================================
# 提供智能告警分析、优先级排序、告警聚合和多渠道通知
# =============================================================================

# 防止重复加载
if [ -n "${_AI_ALERT_MANAGER_LOADED:-}" ]; then
    return 0
fi
_AI_ALERT_MANAGER_LOADED=1

# 加载依赖模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ai-core.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/api-client.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/prompt-templates.sh" 2>/dev/null || true

# 告警配置
ALERT_AGGREGATION_WINDOW="${ALERT_AGGREGATION_WINDOW:-300}"  # 聚合窗口 (秒)
ALERT_MIN_INTERVAL="${ALERT_MIN_INTERVAL:-60}"               # 最小告警间隔 (秒)
ALERT_HISTORY_FILE="${ALERT_HISTORY_FILE:-/tmp/aicd-alerts.log}"
ALERT_STATE_FILE="${ALERT_STATE_FILE:-/tmp/aicd-alert-state.json}"

# 告警级别
ALERT_LEVEL_CRITICAL=1
ALERT_LEVEL_HIGH=2
ALERT_LEVEL_MEDIUM=3
ALERT_LEVEL_LOW=4

# Slack Webhook URL (可通过环境变量设置)
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"

# =============================================================================
# 告警记录和状态管理
# =============================================================================

# 初始化告警状态
_alert_init_state() {
    if [ ! -f "${ALERT_STATE_FILE}" ]; then
        echo '{"last_alert_time": 0, "alert_count": 0, "aggregated_alerts": []}' > "${ALERT_STATE_FILE}"
    fi
}

# 读取告警状态
_alert_read_state() {
    _alert_init_state
    cat "${ALERT_STATE_FILE}" 2>/dev/null || echo '{}'
}

# 更新告警状态
_alert_update_state() {
    local key="$1"
    local value="$2"

    _alert_init_state
    local state
    state=$(_alert_read_state)

    # 使用 jq 更新状态 (如果可用)
    if command -v jq &>/dev/null; then
        echo "${state}" | jq --arg k "${key}" --arg v "${value}" '.[$k] = $v' > "${ALERT_STATE_FILE}"
    fi
}

# 记录告警到历史
_alert_log_history() {
    local level="$1"
    local title="$2"
    local message="$3"

    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    mkdir -p "$(dirname "${ALERT_HISTORY_FILE}")" 2>/dev/null
    echo "[${timestamp}] [${level}] ${title}: ${message}" >> "${ALERT_HISTORY_FILE}"
}

# 获取最近的告警历史
_alert_get_recent_history() {
    local lines="${1:-50}"

    if [ -f "${ALERT_HISTORY_FILE}" ]; then
        tail -n "${lines}" "${ALERT_HISTORY_FILE}" 2>/dev/null
    fi
}

# =============================================================================
# 告警发送渠道
# =============================================================================

# 发送日志告警
_alert_send_log() {
    local level="$1"
    local title="$2"
    local message="$3"

    local color=""
    case "${level}" in
        CRITICAL) color="${AI_RED}" ;;
        HIGH) color="${AI_YELLOW}" ;;
        MEDIUM) color="${AI_BLUE}" ;;
        LOW) color="${AI_GREEN}" ;;
    esac

    echo -e "${color}[ALERT][${level}] ${title}${AI_NC}"
    echo "${message}"
    echo ""

    _alert_log_history "${level}" "${title}" "${message}"
}

# 发送 Slack 告警
_alert_send_slack() {
    local level="$1"
    local title="$2"
    local message="$3"

    if [ -z "${SLACK_WEBHOOK_URL}" ]; then
        ai_log_debug "Slack Webhook URL 未配置，跳过 Slack 通知"
        return 0
    fi

    local color=""
    case "${level}" in
        CRITICAL) color="danger" ;;
        HIGH) color="warning" ;;
        MEDIUM) color="#439FE0" ;;
        LOW) color="good" ;;
    esac

    local payload
    payload=$(jq -n \
        --arg color "${color}" \
        --arg title "[${level}] ${title}" \
        --arg text "${message}" \
        --arg ts "$(date +%s)" \
        '{
            attachments: [{
                color: $color,
                title: $title,
                text: $text,
                ts: $ts
            }]
        }')

    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "${payload}" \
        "${SLACK_WEBHOOK_URL}" >/dev/null 2>&1

    if [ $? -eq 0 ]; then
        ai_log_debug "Slack 告警已发送"
    else
        ai_log_warn "Slack 告警发送失败"
    fi
}

# 发送邮件告警 (需要配置 mail 命令)
_alert_send_email() {
    local level="$1"
    local title="$2"
    local message="$3"
    local recipient="${ALERT_EMAIL_RECIPIENT:-}"

    if [ -z "${recipient}" ]; then
        ai_log_debug "邮件收件人未配置，跳过邮件通知"
        return 0
    fi

    if ! command -v mail &>/dev/null; then
        ai_log_debug "mail 命令不可用，跳过邮件通知"
        return 0
    fi

    echo "${message}" | mail -s "[AICD Alert][${level}] ${title}" "${recipient}"

    if [ $? -eq 0 ]; then
        ai_log_debug "邮件告警已发送"
    else
        ai_log_warn "邮件告警发送失败"
    fi
}

# =============================================================================
# 告警发送和管理
# =============================================================================

# 发送告警
# 用法: ai_alert <level> <title> <message> [channels]
ai_alert() {
    local level="$1"
    local title="$2"
    local message="$3"
    local channels="${4:-log}"

    # 验证告警级别
    case "${level}" in
        CRITICAL|HIGH|MEDIUM|LOW) ;;
        *)
            ai_log_warn "无效的告警级别: ${level}，使用 MEDIUM"
            level="MEDIUM"
            ;;
    esac

    ai_log_info "发送告警: [${level}] ${title}"

    # 检查告警间隔
    local now
    now=$(date +%s)
    local state
    state=$(_alert_read_state)
    local last_alert_time=0

    if command -v jq &>/dev/null; then
        last_alert_time=$(echo "${state}" | jq -r '.last_alert_time // 0')
    fi

    local elapsed=$((now - last_alert_time))
    if [ "${elapsed}" -lt "${ALERT_MIN_INTERVAL}" ] && [ "${level}" != "CRITICAL" ]; then
        ai_log_debug "告警间隔过短 (${elapsed}s < ${ALERT_MIN_INTERVAL}s)，已聚合"
        # 可以将告警添加到聚合列表
        return 0
    fi

    # 更新最后告警时间
    _alert_update_state "last_alert_time" "${now}"

    # 发送到各渠道
    IFS=',' read -ra channel_list <<< "${channels}"
    for channel in "${channel_list[@]}"; do
        case "${channel}" in
            log)
                _alert_send_log "${level}" "${title}" "${message}"
                ;;
            slack)
                _alert_send_slack "${level}" "${title}" "${message}"
                ;;
            email)
                _alert_send_email "${level}" "${title}" "${message}"
                ;;
            *)
                ai_log_warn "未知的告警渠道: ${channel}"
                ;;
        esac
    done
}

# 快捷告警函数
ai_alert_critical() {
    ai_alert "CRITICAL" "$1" "$2" "${3:-log,slack}"
}

ai_alert_high() {
    ai_alert "HIGH" "$1" "$2" "${3:-log,slack}"
}

ai_alert_medium() {
    ai_alert "MEDIUM" "$1" "$2" "${3:-log}"
}

ai_alert_low() {
    ai_alert "LOW" "$1" "$2" "${3:-log}"
}

# =============================================================================
# AI 告警分析
# =============================================================================

# 分析告警
# 用法: ai_alert_analyze <alerts>
ai_alert_analyze() {
    local alerts="$1"

    if [ -z "${alerts}" ]; then
        alerts=$(_alert_get_recent_history)
    fi

    if [ -z "${alerts}" ]; then
        ai_log_info "没有告警需要分析"
        return 0
    fi

    if ! ai_is_enabled; then
        echo "=== 最近告警 ==="
        echo "${alerts}"
        return 0
    fi

    ai_log_info "使用 AI 分析告警..."

    local system_prompt
    system_prompt=$(ai_get_system_prompt "alert_analyzer")
    local user_prompt
    user_prompt=$(ai_prompt_alert_analysis "${alerts}")

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# 告警优先级排序
# 用法: ai_alert_prioritize <alerts>
ai_alert_prioritize() {
    local alerts="$1"

    if [ -z "${alerts}" ]; then
        alerts=$(_alert_get_recent_history)
    fi

    if [ -z "${alerts}" ]; then
        ai_log_info "没有告警需要排序"
        return 0
    fi

    if ! ai_is_enabled; then
        # 简单排序: CRITICAL > HIGH > MEDIUM > LOW
        echo "=== 告警优先级排序 ==="
        echo "${alerts}" | grep -E '\[CRITICAL\]' || true
        echo "${alerts}" | grep -E '\[HIGH\]' || true
        echo "${alerts}" | grep -E '\[MEDIUM\]' || true
        echo "${alerts}" | grep -E '\[LOW\]' || true
        return 0
    fi

    ai_log_info "使用 AI 进行告警优先级排序..."

    local system_prompt
    system_prompt=$(ai_get_system_prompt "alert_analyzer")
    local user_prompt="请对以下告警按照业务影响和紧急程度进行优先级排序，并说明理由。

告警列表:
\`\`\`
${alerts}
\`\`\`

请提供:
1. 优先处理顺序
2. 每个告警的紧急程度评估
3. 建议的响应时间
4. 可能的关联关系"

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# 告警聚合
# 用法: ai_alert_aggregate
ai_alert_aggregate() {
    local alerts
    alerts=$(_alert_get_recent_history 100)

    if [ -z "${alerts}" ]; then
        ai_log_info "没有告警需要聚合"
        return 0
    fi

    if ! ai_is_enabled; then
        # 简单聚合: 按类型统计
        echo "=== 告警聚合统计 ==="
        echo "CRITICAL: $(echo "${alerts}" | grep -c '\[CRITICAL\]' || echo 0)"
        echo "HIGH: $(echo "${alerts}" | grep -c '\[HIGH\]' || echo 0)"
        echo "MEDIUM: $(echo "${alerts}" | grep -c '\[MEDIUM\]' || echo 0)"
        echo "LOW: $(echo "${alerts}" | grep -c '\[LOW\]' || echo 0)"
        return 0
    fi

    ai_log_info "使用 AI 进行告警聚合分析..."

    local system_prompt
    system_prompt=$(ai_get_system_prompt "alert_analyzer")
    local user_prompt="请分析以下告警并进行智能聚合，识别相关的告警组和根本问题。

告警列表:
\`\`\`
${alerts}
\`\`\`

请提供:
1. 告警分组 (相关告警归类)
2. 每组的根本原因推测
3. 去重后的关键告警
4. 统一的处理建议"

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# 发送通知 (带 AI 分析)
# 用法: ai_alert_notify <level> <title> <message>
ai_alert_notify() {
    local level="$1"
    local title="$2"
    local message="$3"

    # 首先发送原始告警
    ai_alert "${level}" "${title}" "${message}" "log,slack"

    # 如果是高优先级告警且 AI 启用，生成建议
    if [ "${level}" = "CRITICAL" ] || [ "${level}" = "HIGH" ]; then
        if ai_is_enabled; then
            ai_log_info "生成 AI 响应建议..."

            local system_prompt
            system_prompt=$(ai_get_system_prompt "alert_analyzer")
            local user_prompt="系统触发了以下高优先级告警，请提供紧急响应建议。

告警级别: ${level}
告警标题: ${title}
告警详情:
${message}

请提供:
1. 立即采取的行动
2. 需要通知的相关人员
3. 可能的影响范围
4. 临时缓解措施"

            local suggestion
            suggestion=$(ai_api_call "${system_prompt}" "${user_prompt}")

            if [ -n "${suggestion}" ]; then
                echo ""
                echo "=== AI 响应建议 ==="
                echo "${suggestion}"
            fi
        fi
    fi
}

# =============================================================================
# 告警规则
# =============================================================================

# 检查告警规则
# 用法: ai_check_alert_rules <metrics>
ai_check_alert_rules() {
    local metrics="$1"

    # 从指标中提取数值并检查阈值
    local cpu_usage memory_usage disk_usage

    # 尝试解析指标
    cpu_usage=$(echo "${metrics}" | grep -oP 'CPU.*?:\s*\K\d+' | head -1)
    memory_usage=$(echo "${metrics}" | grep -oP '内存.*?:\s*\K\d+' | head -1)
    disk_usage=$(echo "${metrics}" | grep -oP '磁盘.*?:\s*\K\d+' | head -1)

    # CPU 告警规则
    if [ -n "${cpu_usage}" ]; then
        if [ "${cpu_usage}" -gt 90 ]; then
            ai_alert_critical "CPU 使用率过高" "CPU 使用率达到 ${cpu_usage}%，系统可能面临性能问题"
        elif [ "${cpu_usage}" -gt 80 ]; then
            ai_alert_high "CPU 使用率警告" "CPU 使用率达到 ${cpu_usage}%，建议关注"
        fi
    fi

    # 内存告警规则
    if [ -n "${memory_usage}" ]; then
        if [ "${memory_usage}" -gt 90 ]; then
            ai_alert_critical "内存使用率过高" "内存使用率达到 ${memory_usage}%，可能导致 OOM"
        elif [ "${memory_usage}" -gt 80 ]; then
            ai_alert_high "内存使用率警告" "内存使用率达到 ${memory_usage}%，建议关注"
        fi
    fi

    # 磁盘告警规则
    if [ -n "${disk_usage}" ]; then
        if [ "${disk_usage}" -gt 90 ]; then
            ai_alert_critical "磁盘空间不足" "磁盘使用率达到 ${disk_usage}%，需要立即清理"
        elif [ "${disk_usage}" -gt 80 ]; then
            ai_alert_high "磁盘空间警告" "磁盘使用率达到 ${disk_usage}%，建议清理"
        fi
    fi
}

# =============================================================================
# 告警管理
# =============================================================================

# 清除告警历史
ai_alert_clear_history() {
    if [ -f "${ALERT_HISTORY_FILE}" ]; then
        rm -f "${ALERT_HISTORY_FILE}"
        ai_log_info "告警历史已清除"
    fi
}

# 显示告警统计
ai_alert_stats() {
    echo "=== 告警统计 ==="

    if [ -f "${ALERT_HISTORY_FILE}" ]; then
        local total critical high medium low
        total=$(wc -l < "${ALERT_HISTORY_FILE}")
        critical=$(grep -c '\[CRITICAL\]' "${ALERT_HISTORY_FILE}" 2>/dev/null || echo 0)
        high=$(grep -c '\[HIGH\]' "${ALERT_HISTORY_FILE}" 2>/dev/null || echo 0)
        medium=$(grep -c '\[MEDIUM\]' "${ALERT_HISTORY_FILE}" 2>/dev/null || echo 0)
        low=$(grep -c '\[LOW\]' "${ALERT_HISTORY_FILE}" 2>/dev/null || echo 0)

        echo "总告警数: ${total}"
        echo "CRITICAL: ${critical}"
        echo "HIGH: ${high}"
        echo "MEDIUM: ${medium}"
        echo "LOW: ${low}"
    else
        echo "暂无告警记录"
    fi
}
