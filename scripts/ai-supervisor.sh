#!/bin/bash

# =============================================================================
# AI 监督主入口脚本
# =============================================================================
# 统一的 AI 监督功能命令行工具
# =============================================================================

set -euo pipefail

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

# 加载 AI 模块
source "${PROJECT_ROOT}/lib/ai/ai-core.sh"
source "${PROJECT_ROOT}/lib/ai/api-client.sh"
source "${PROJECT_ROOT}/lib/ai/prompt-templates.sh"
source "${PROJECT_ROOT}/lib/ai/log-analyzer.sh"
source "${PROJECT_ROOT}/lib/ai/config-advisor.sh"
source "${PROJECT_ROOT}/lib/ai/health-analyzer.sh"
source "${PROJECT_ROOT}/lib/ai/alert-manager.sh"

# 版本
VERSION="1.0.0"

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    cat << EOF
AI 监督工具 v${VERSION}

使用方法:
  ${0##*/} <命令> [选项]

命令:
  日志分析:
    analyze-logs <file|dir>     分析日志文件或目录
    detect-errors <file>        检测错误模式
    suggest-fixes <error>       建议修复方案
    summarize-logs <file|dir>   生成日志摘要
    log-stats <file|dir>        显示日志统计

  配置分析:
    audit-config <file>         审计配置文件
    check-security <file>       安全检查
    optimize-config <file>      配置优化建议
    validate-yaml <file>        验证 YAML 文件
    compare-configs <f1> <f2>   比较配置文件
    suggest-config <type>       生成配置模板建议

  健康检查:
    health-check                执行健康检查
    health-report [file]        生成健康报告
    predict-issues              预测潜在问题
    quick-diagnosis             快速诊断
    capacity-planning [rate]    容量规划建议

  告警管理:
    alert <level> <title> <msg> 发送告警
    alert-analyze               分析最近告警
    alert-prioritize            告警优先级排序
    alert-aggregate             告警聚合分析
    alert-stats                 告警统计
    alert-clear                 清除告警历史

  系统:
    status                      显示 AI 模块状态
    test-api                    测试 API 连接
    ask <question>              直接向 AI 提问
    templates                   列出可用模板
    help                        显示帮助信息
    version                     显示版本信息

选项:
  --provider <claude|openai>    指定 AI 提供商
  --config <file>               指定配置文件
  --verbose                     显示详细信息
  --no-color                    禁用颜色输出

环境变量:
  CLAUDE_API_KEY                Claude API 密钥
  OPENAI_API_KEY                OpenAI API 密钥
  AI_ENABLED                    启用 AI 功能 (true/false)
  AI_PROVIDER                   AI 提供商 (claude/openai)
  AI_LOG_LEVEL                  日志级别 (DEBUG/INFO/WARN/ERROR)

示例:
  # 分析日志
  ${0##*/} analyze-logs /var/log/app.log

  # 审计配置
  ${0##*/} audit-config config/central-config.yaml

  # 健康检查
  ${0##*/} health-check

  # 向 AI 提问
  ${0##*/} ask "如何优化 Docker 镜像大小?"

  # 发送告警
  ${0##*/} alert HIGH "CPU 过高" "CPU 使用率达到 90%"

EOF
}

show_version() {
    echo "AI 监督工具 v${VERSION}"
    echo "AI 模块版本: ${AI_MODULE_VERSION:-unknown}"
}

# =============================================================================
# 参数解析
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --provider)
                AI_PROVIDER="$2"
                shift 2
                ;;
            --config)
                AI_CONFIG_FILE="$2"
                shift 2
                ;;
            --verbose)
                AI_LOG_LEVEL="DEBUG"
                shift
                ;;
            --no-color)
                AI_RED=""
                AI_GREEN=""
                AI_YELLOW=""
                AI_BLUE=""
                AI_NC=""
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            *)
                break
                ;;
        esac
    done

    REMAINING_ARGS=("$@")
}

# =============================================================================
# 命令处理
# =============================================================================

run_command() {
    local cmd="${1:-help}"
    shift || true

    case "${cmd}" in
        # 日志分析命令
        analyze-logs)
            ai_analyze_logs "$@"
            ;;
        detect-errors)
            ai_detect_errors "$@"
            ;;
        suggest-fixes)
            ai_suggest_fixes "$@"
            ;;
        summarize-logs)
            ai_summarize_logs "$@"
            ;;
        log-stats)
            ai_log_stats "$@"
            ;;

        # 配置分析命令
        audit-config)
            ai_audit_config "$@"
            ;;
        check-security)
            ai_check_security "$@"
            ;;
        optimize-config)
            ai_optimize_config "$@"
            ;;
        validate-yaml)
            ai_validate_yaml "$@"
            ;;
        compare-configs)
            ai_compare_configs "$@"
            ;;
        suggest-config)
            ai_suggest_config "$@"
            ;;

        # 健康检查命令
        health-check|health)
            ai_health_check "$@"
            ;;
        health-report)
            ai_generate_report "$@"
            ;;
        predict-issues)
            ai_predict_issues "$@"
            ;;
        quick-diagnosis|diagnosis)
            ai_quick_diagnosis "$@"
            ;;
        capacity-planning)
            ai_capacity_planning "$@"
            ;;

        # 告警管理命令
        alert)
            local level="${1:-MEDIUM}"
            local title="${2:-Alert}"
            local message="${3:-No message}"
            shift 3 || true
            ai_alert "${level}" "${title}" "${message}" "$@"
            ;;
        alert-analyze)
            ai_alert_analyze "$@"
            ;;
        alert-prioritize)
            ai_alert_prioritize "$@"
            ;;
        alert-aggregate)
            ai_alert_aggregate "$@"
            ;;
        alert-stats)
            ai_alert_stats "$@"
            ;;
        alert-clear)
            ai_alert_clear_history "$@"
            ;;

        # 系统命令
        status)
            ai_status
            ;;
        test-api)
            ai_api_test "$@"
            ;;
        ask)
            if [ -z "$1" ]; then
                echo "请提供问题"
                exit 1
            fi
            ai_ask "$*"
            ;;
        templates)
            ai_list_templates
            ;;
        help|--help|-h)
            show_help
            ;;
        version|--version|-v)
            show_version
            ;;

        # 未知命令
        *)
            echo "未知命令: ${cmd}"
            echo "使用 '${0##*/} help' 查看帮助"
            exit 1
            ;;
    esac
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    # 解析参数
    parse_args "$@"

    # 初始化 AI 模块
    ai_init "${AI_CONFIG_FILE:-}"

    # 运行命令
    run_command "${REMAINING_ARGS[@]}"
}

# 运行
main "$@"
