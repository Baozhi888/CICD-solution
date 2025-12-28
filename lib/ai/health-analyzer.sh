#!/bin/bash

# =============================================================================
# AI 健康分析器
# =============================================================================
# 使用 AI 分析系统健康状况，提供评估和预警
# =============================================================================

# 防止重复加载
if [ -n "${_AI_HEALTH_ANALYZER_LOADED:-}" ]; then
    return 0
fi
_AI_HEALTH_ANALYZER_LOADED=1

# 加载依赖模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ai-core.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/api-client.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/prompt-templates.sh" 2>/dev/null || true

# 健康分析配置
HEALTH_THRESHOLD_CRITICAL="${HEALTH_THRESHOLD_CRITICAL:-30}"
HEALTH_THRESHOLD_WARNING="${HEALTH_THRESHOLD_WARNING:-60}"
HEALTH_THRESHOLD_HEALTHY="${HEALTH_THRESHOLD_HEALTHY:-80}"

# =============================================================================
# 系统指标收集
# =============================================================================

# 获取 CPU 使用率
_health_get_cpu_usage() {
    if command -v top &>/dev/null; then
        # Linux
        if [ -f /proc/stat ]; then
            local cpu_line
            cpu_line=$(head -1 /proc/stat)
            local user nice system idle iowait irq softirq
            read -r _ user nice system idle iowait irq softirq _ <<< "${cpu_line}"
            local total=$((user + nice + system + idle + iowait + irq + softirq))
            local active=$((total - idle - iowait))
            echo "$((active * 100 / total))"
        # macOS
        elif command -v sysctl &>/dev/null; then
            top -l 1 | grep "CPU usage" | awk '{print int($3)}'
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

# 获取内存使用率
_health_get_memory_usage() {
    if [ -f /proc/meminfo ]; then
        # Linux
        local total available
        total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        if [ -z "${available}" ]; then
            available=$(grep MemFree /proc/meminfo | awk '{print $2}')
        fi
        echo "$(((total - available) * 100 / total))"
    elif command -v sysctl &>/dev/null; then
        # macOS
        local page_size pages_free pages_active pages_inactive pages_wired
        page_size=$(sysctl -n hw.pagesize 2>/dev/null || echo 4096)
        pages_free=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        pages_active=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        pages_inactive=$(vm_stat | grep "Pages inactive" | awk '{print $3}' | tr -d '.')
        pages_wired=$(vm_stat | grep "Pages wired" | awk '{print $4}' | tr -d '.')
        local total_mem
        total_mem=$(sysctl -n hw.memsize 2>/dev/null)
        local used_mem=$(((pages_active + pages_wired) * page_size))
        echo "$((used_mem * 100 / total_mem))"
    else
        echo "N/A"
    fi
}

# 获取磁盘使用率
_health_get_disk_usage() {
    local path="${1:-/}"
    if command -v df &>/dev/null; then
        df -P "${path}" 2>/dev/null | tail -1 | awk '{print int($5)}'
    else
        echo "N/A"
    fi
}

# 获取系统负载
_health_get_load_average() {
    if [ -f /proc/loadavg ]; then
        cut -d' ' -f1 /proc/loadavg
    elif command -v uptime &>/dev/null; then
        uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' '
    else
        echo "N/A"
    fi
}

# 获取进程数
_health_get_process_count() {
    if command -v ps &>/dev/null; then
        ps aux 2>/dev/null | wc -l
    else
        echo "N/A"
    fi
}

# 获取网络连接数
_health_get_network_connections() {
    if command -v ss &>/dev/null; then
        ss -t state established 2>/dev/null | wc -l
    elif command -v netstat &>/dev/null; then
        netstat -an 2>/dev/null | grep ESTABLISHED | wc -l
    else
        echo "N/A"
    fi
}

# 收集所有系统指标
_health_collect_metrics() {
    local metrics=""

    metrics+="=== 系统指标 ===\n"
    metrics+="时间: $(date '+%Y-%m-%d %H:%M:%S')\n"
    metrics+="主机: $(hostname 2>/dev/null || echo 'unknown')\n"
    metrics+="系统: $(uname -s) $(uname -r)\n"
    metrics+="\n"

    metrics+="--- 资源使用 ---\n"
    metrics+="CPU 使用率: $(_health_get_cpu_usage)%\n"
    metrics+="内存使用率: $(_health_get_memory_usage)%\n"
    metrics+="磁盘使用率 (/): $(_health_get_disk_usage /)%\n"
    metrics+="系统负载: $(_health_get_load_average)\n"
    metrics+="\n"

    metrics+="--- 进程和网络 ---\n"
    metrics+="进程数: $(_health_get_process_count)\n"
    metrics+="网络连接数: $(_health_get_network_connections)\n"
    metrics+="\n"

    # 检查关键服务
    metrics+="--- 服务状态 ---\n"
    for service in docker nginx mysql postgresql redis; do
        if command -v systemctl &>/dev/null; then
            if systemctl is-active --quiet "${service}" 2>/dev/null; then
                metrics+="${service}: 运行中\n"
            elif systemctl list-unit-files | grep -q "${service}" 2>/dev/null; then
                metrics+="${service}: 已停止\n"
            fi
        elif command -v service &>/dev/null; then
            if service "${service}" status &>/dev/null; then
                metrics+="${service}: 运行中\n"
            fi
        fi
    done

    echo -e "${metrics}"
}

# =============================================================================
# 健康评分计算
# =============================================================================

# 计算健康评分 (0-100)
_health_calculate_score() {
    local cpu_usage memory_usage disk_usage
    cpu_usage=$(_health_get_cpu_usage)
    memory_usage=$(_health_get_memory_usage)
    disk_usage=$(_health_get_disk_usage /)

    # 默认值处理
    [ "${cpu_usage}" = "N/A" ] && cpu_usage=0
    [ "${memory_usage}" = "N/A" ] && memory_usage=0
    [ "${disk_usage}" = "N/A" ] && disk_usage=0

    # 计算各项分数 (资源使用率越低分数越高)
    local cpu_score=$((100 - cpu_usage))
    local memory_score=$((100 - memory_usage))
    local disk_score=$((100 - disk_usage))

    # 加权平均 (CPU 30%, 内存 40%, 磁盘 30%)
    local total_score=$(((cpu_score * 30 + memory_score * 40 + disk_score * 30) / 100))

    echo "${total_score}"
}

# 获取健康状态
_health_get_status() {
    local score="$1"

    if [ "${score}" -ge "${HEALTH_THRESHOLD_HEALTHY}" ]; then
        echo "HEALTHY"
    elif [ "${score}" -ge "${HEALTH_THRESHOLD_WARNING}" ]; then
        echo "WARNING"
    elif [ "${score}" -ge "${HEALTH_THRESHOLD_CRITICAL}" ]; then
        echo "CRITICAL"
    else
        echo "EMERGENCY"
    fi
}

# =============================================================================
# 健康检查功能
# =============================================================================

# 执行健康检查
# 用法: ai_health_check
ai_health_check() {
    ai_log_info "执行系统健康检查..."

    local score status
    score=$(_health_calculate_score)
    status=$(_health_get_status "${score}")

    # 收集指标
    local metrics
    metrics=$(_health_collect_metrics)

    echo "=========================================="
    echo "系统健康报告"
    echo "=========================================="
    echo ""
    echo "健康评分: ${score}/100"
    echo "状态: ${status}"
    echo ""
    echo -e "${metrics}"

    # 返回状态码
    case "${status}" in
        HEALTHY) return 0 ;;
        WARNING) return 1 ;;
        CRITICAL) return 2 ;;
        EMERGENCY) return 3 ;;
    esac
}

# 问题预测
# 用法: ai_predict_issues
ai_predict_issues() {
    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "分析潜在问题..."

    # 收集当前指标
    local metrics
    metrics=$(_health_collect_metrics)

    local system_prompt
    system_prompt=$(ai_get_system_prompt "health_analyzer")
    local user_prompt="基于以下系统指标，请预测可能出现的问题并提供预防建议。

${metrics}

请分析:
1. 哪些指标可能在未来出现问题
2. 潜在的瓶颈和风险点
3. 预防措施和优化建议
4. 需要监控的关键指标"

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# 分析指标
# 用法: ai_analyze_metrics [custom_metrics]
ai_analyze_metrics() {
    local custom_metrics="${1:-}"

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "分析系统指标..."

    # 收集指标
    local metrics
    if [ -n "${custom_metrics}" ]; then
        metrics="${custom_metrics}"
    else
        metrics=$(_health_collect_metrics)
    fi

    local system_prompt
    system_prompt=$(ai_get_system_prompt "health_analyzer")
    local user_prompt
    user_prompt=$(ai_prompt_health_report "${metrics}")

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# 生成健康报告
# 用法: ai_generate_report [output_file]
ai_generate_report() {
    local output_file="${1:-}"

    ai_log_info "生成健康报告..."

    local report=""
    report+="# 系统健康报告\n"
    report+="生成时间: $(date '+%Y-%m-%d %H:%M:%S')\n\n"

    # 基础健康检查
    report+="## 基础健康检查\n"
    local score status
    score=$(_health_calculate_score)
    status=$(_health_get_status "${score}")
    report+="- 健康评分: ${score}/100\n"
    report+="- 状态: ${status}\n\n"

    # 系统指标
    report+="## 系统指标\n"
    report+="\`\`\`\n"
    report+=$(_health_collect_metrics)
    report+="\`\`\`\n\n"

    # AI 分析 (如果启用)
    if ai_is_enabled; then
        report+="## AI 深度分析\n"
        local ai_analysis
        ai_analysis=$(ai_analyze_metrics 2>/dev/null)
        if [ -n "${ai_analysis}" ]; then
            report+="${ai_analysis}\n"
        else
            report+="AI 分析不可用\n"
        fi
    fi

    # 输出报告
    if [ -n "${output_file}" ]; then
        echo -e "${report}" > "${output_file}"
        ai_log_info "报告已保存到: ${output_file}"
    else
        echo -e "${report}"
    fi
}

# =============================================================================
# 容量规划
# =============================================================================

# 容量规划建议
# 用法: ai_capacity_planning [growth_rate]
ai_capacity_planning() {
    local growth_rate="${1:-10}"  # 预期增长率 (%)

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "生成容量规划建议 (预期增长率: ${growth_rate}%)..."

    local metrics
    metrics=$(_health_collect_metrics)

    local system_prompt
    system_prompt=$(ai_get_system_prompt "health_analyzer")
    local user_prompt="基于以下系统指标和 ${growth_rate}% 的预期增长率，请提供容量规划建议。

当前系统指标:
${metrics}

请分析:
1. 当前资源使用情况
2. 预计达到瓶颈的时间
3. 推荐的扩容方案
4. 成本优化建议
5. 监控和告警阈值建议"

    ai_api_call "${system_prompt}" "${user_prompt}"
}

# =============================================================================
# 定期检查
# =============================================================================

# 启动定期健康检查
# 用法: ai_health_watch [interval_seconds] [callback]
ai_health_watch() {
    local interval="${1:-300}"  # 默认 5 分钟
    local callback="${2:-_health_default_callback}"

    ai_log_info "启动健康监控 (间隔: ${interval}s)"
    ai_log_info "按 Ctrl+C 停止监控"

    while true; do
        local score status
        score=$(_health_calculate_score)
        status=$(_health_get_status "${score}")

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] 健康评分: ${score}/100 状态: ${status}"

        # 如果状态异常，触发回调
        if [ "${status}" != "HEALTHY" ]; then
            ${callback} "${score}" "${status}"
        fi

        sleep "${interval}"
    done
}

# 默认回调函数
_health_default_callback() {
    local score="$1"
    local status="$2"

    ai_log_warn "健康状态异常: ${status} (评分: ${score})"

    # 如果 AI 启用，生成建议
    if ai_is_enabled; then
        ai_log_info "生成 AI 建议..."
        ai_predict_issues
    fi
}

# =============================================================================
# 快速诊断
# =============================================================================

# 快速诊断
# 用法: ai_quick_diagnosis
ai_quick_diagnosis() {
    echo "=== 快速诊断 ==="
    echo ""

    # CPU 检查
    local cpu_usage
    cpu_usage=$(_health_get_cpu_usage)
    echo -n "CPU: ${cpu_usage}% "
    if [ "${cpu_usage}" -gt 80 ]; then
        echo "[高]"
    elif [ "${cpu_usage}" -gt 60 ]; then
        echo "[中]"
    else
        echo "[正常]"
    fi

    # 内存检查
    local memory_usage
    memory_usage=$(_health_get_memory_usage)
    echo -n "内存: ${memory_usage}% "
    if [ "${memory_usage}" -gt 80 ]; then
        echo "[高]"
    elif [ "${memory_usage}" -gt 60 ]; then
        echo "[中]"
    else
        echo "[正常]"
    fi

    # 磁盘检查
    local disk_usage
    disk_usage=$(_health_get_disk_usage /)
    echo -n "磁盘: ${disk_usage}% "
    if [ "${disk_usage}" -gt 80 ]; then
        echo "[高]"
    elif [ "${disk_usage}" -gt 60 ]; then
        echo "[中]"
    else
        echo "[正常]"
    fi

    # 负载检查
    local load_avg
    load_avg=$(_health_get_load_average)
    echo "负载: ${load_avg}"

    echo ""
    echo "总体评分: $(_health_calculate_score)/100"
    echo "状态: $(_health_get_status "$(_health_calculate_score)")"
}
