#!/bin/bash

# =============================================================================
# AI 提示词模板库
# =============================================================================
# 提供各种场景下的提示词模板
# 支持动态参数替换和模板组合
# =============================================================================

# 防止重复加载
if [ -n "${_AI_PROMPT_TEMPLATES_LOADED:-}" ]; then
    return 0
fi
_AI_PROMPT_TEMPLATES_LOADED=1

# =============================================================================
# 系统提示词模板
# =============================================================================

# CI/CD 专家系统提示词
AI_PROMPT_SYSTEM_CICD_EXPERT='You are an expert CI/CD engineer and DevOps specialist with deep knowledge of:
- Shell scripting and Bash best practices
- CI/CD pipelines (GitHub Actions, GitLab CI, Jenkins)
- Container technologies (Docker, Kubernetes)
- Infrastructure as Code (Terraform, Ansible)
- Log analysis and troubleshooting
- Security best practices

Provide concise, actionable advice. Use code examples when helpful.
Respond in Chinese when the input is in Chinese.'

# 日志分析系统提示词
AI_PROMPT_SYSTEM_LOG_ANALYZER='You are a log analysis expert specializing in:
- Error pattern recognition
- Root cause analysis
- Performance issue detection
- Security incident identification
- Trend analysis

Your analysis should be:
1. Structured and clear
2. Prioritized by severity
3. Actionable with specific recommendations
4. Include relevant log excerpts

Respond in Chinese when the input is in Chinese.'

# 配置审计系统提示词
AI_PROMPT_SYSTEM_CONFIG_ADVISOR='You are a configuration expert specializing in:
- YAML/JSON configuration validation
- Security hardening
- Performance optimization
- Best practices compliance
- Environment-specific configurations

Your recommendations should:
1. Be specific and actionable
2. Include before/after examples
3. Explain the reasoning
4. Prioritize by impact

Respond in Chinese when the input is in Chinese.'

# 健康检查系统提示词
AI_PROMPT_SYSTEM_HEALTH_ANALYZER='You are a system health analyst specializing in:
- Infrastructure monitoring
- Performance metrics analysis
- Capacity planning
- Availability assessment
- Predictive maintenance

Your reports should:
1. Provide a clear health score (0-100)
2. List key metrics and their status
3. Identify potential risks
4. Recommend preventive actions

Respond in Chinese when the input is in Chinese.'

# 告警分析系统提示词
AI_PROMPT_SYSTEM_ALERT_ANALYZER='You are an alert analysis expert specializing in:
- Alert correlation
- False positive detection
- Severity assessment
- Impact analysis
- Response recommendations

Your analysis should:
1. Validate alert authenticity
2. Assess impact scope
3. Provide immediate actions
4. Suggest long-term fixes

Respond in Chinese when the input is in Chinese.'

# =============================================================================
# 用户提示词模板
# =============================================================================

# 日志分析模板
ai_prompt_log_analysis() {
    local log_content="$1"
    local context="${2:-}"

    cat <<EOF
请分析以下日志内容，识别潜在问题并提供解决建议。

## 日志内容
\`\`\`
${log_content}
\`\`\`

${context:+## 上下文信息
${context}

}## 请提供
1. **问题摘要**: 简要描述发现的主要问题
2. **严重程度**: 评估问题的严重性 (Critical/High/Medium/Low)
3. **根因分析**: 分析问题的可能原因
4. **解决建议**: 提供具体的解决步骤
5. **预防措施**: 建议如何预防类似问题
EOF
}

# 错误诊断模板
ai_prompt_error_diagnosis() {
    local error_message="$1"
    local stack_trace="${2:-}"
    local context="${3:-}"

    cat <<EOF
请诊断以下错误并提供修复建议。

## 错误信息
\`\`\`
${error_message}
\`\`\`

${stack_trace:+## 堆栈跟踪
\`\`\`
${stack_trace}
\`\`\`

}${context:+## 上下文
${context}

}## 请提供
1. **错误类型**: 识别错误的类型和类别
2. **根本原因**: 分析导致错误的根本原因
3. **修复方案**: 提供具体的修复步骤
4. **代码示例**: 如适用，提供修复代码示例
5. **验证方法**: 如何验证问题已修复
EOF
}

# 配置审计模板
ai_prompt_config_audit() {
    local config_content="$1"
    local config_type="${2:-YAML}"
    local focus_areas="${3:-security,performance,best-practices}"

    cat <<EOF
请审计以下 ${config_type} 配置文件。

## 配置内容
\`\`\`${config_type,,}
${config_content}
\`\`\`

## 审计重点
${focus_areas}

## 请提供
1. **安全问题**: 识别潜在的安全风险
2. **性能问题**: 识别可能影响性能的配置
3. **最佳实践**: 对照最佳实践的偏差
4. **改进建议**: 具体的配置改进建议
5. **优化后配置**: 提供优化后的配置示例
EOF
}

# 配置优化模板
ai_prompt_config_optimize() {
    local config_content="$1"
    local optimization_goal="${2:-performance}"

    cat <<EOF
请优化以下配置以提升 ${optimization_goal}。

## 当前配置
\`\`\`yaml
${config_content}
\`\`\`

## 优化目标
${optimization_goal}

## 请提供
1. **当前问题**: 当前配置存在的问题
2. **优化建议**: 详细的优化建议列表
3. **优化配置**: 完整的优化后配置
4. **预期效果**: 优化后的预期改善
5. **注意事项**: 实施优化时的注意事项
EOF
}

# 健康报告模板
ai_prompt_health_report() {
    local metrics="$1"
    local thresholds="${2:-}"

    cat <<EOF
请基于以下指标生成系统健康报告。

## 系统指标
\`\`\`
${metrics}
\`\`\`

${thresholds:+## 阈值标准
${thresholds}

}## 请提供
1. **健康评分**: 整体健康评分 (0-100)
2. **状态概览**: 各组件状态摘要
3. **异常指标**: 需要关注的异常指标
4. **风险预警**: 潜在风险和预警
5. **优化建议**: 改善系统健康的建议
EOF
}

# 告警分析模板
ai_prompt_alert_analysis() {
    local alerts="$1"
    local history="${2:-}"

    cat <<EOF
请分析以下告警并提供响应建议。

## 当前告警
\`\`\`
${alerts}
\`\`\`

${history:+## 历史告警
\`\`\`
${history}
\`\`\`

}## 请提供
1. **告警摘要**: 告警的总体情况
2. **优先级排序**: 按重要性排序告警
3. **关联分析**: 告警之间的关联关系
4. **响应建议**: 针对每个告警的响应措施
5. **根因推测**: 可能的根本原因
EOF
}

# Shell 脚本审查模板
ai_prompt_script_review() {
    local script_content="$1"
    local script_name="${2:-script.sh}"

    cat <<EOF
请审查以下 Shell 脚本并提供改进建议。

## 脚本名称
${script_name}

## 脚本内容
\`\`\`bash
${script_content}
\`\`\`

## 请提供
1. **安全问题**: 潜在的安全漏洞
2. **代码质量**: 代码风格和可读性问题
3. **性能问题**: 可能的性能瓶颈
4. **兼容性**: 跨平台兼容性问题
5. **改进建议**: 具体的代码改进建议
6. **修复代码**: 关键问题的修复代码
EOF
}

# 部署建议模板
ai_prompt_deployment_advice() {
    local deployment_config="$1"
    local target_env="${2:-production}"

    cat <<EOF
请审查以下部署配置并提供 ${target_env} 环境的建议。

## 部署配置
\`\`\`yaml
${deployment_config}
\`\`\`

## 目标环境
${target_env}

## 请提供
1. **配置检查**: 配置完整性检查
2. **安全审查**: 安全相关的检查点
3. **高可用性**: 高可用配置建议
4. **资源规划**: 资源配置建议
5. **回滚策略**: 部署失败的回滚建议
6. **监控建议**: 部署后的监控要点
EOF
}

# =============================================================================
# 模板工具函数
# =============================================================================

# 获取系统提示词
ai_get_system_prompt() {
    local type="$1"

    case "${type}" in
        cicd|expert)
            echo "${AI_PROMPT_SYSTEM_CICD_EXPERT}"
            ;;
        log|log_analyzer)
            echo "${AI_PROMPT_SYSTEM_LOG_ANALYZER}"
            ;;
        config|config_advisor)
            echo "${AI_PROMPT_SYSTEM_CONFIG_ADVISOR}"
            ;;
        health|health_analyzer)
            echo "${AI_PROMPT_SYSTEM_HEALTH_ANALYZER}"
            ;;
        alert|alert_analyzer)
            echo "${AI_PROMPT_SYSTEM_ALERT_ANALYZER}"
            ;;
        *)
            echo "${AI_PROMPT_SYSTEM_CICD_EXPERT}"
            ;;
    esac
}

# 获取用户提示词
ai_get_user_prompt() {
    local type="$1"
    shift

    case "${type}" in
        log_analysis)
            ai_prompt_log_analysis "$@"
            ;;
        error_diagnosis)
            ai_prompt_error_diagnosis "$@"
            ;;
        config_audit)
            ai_prompt_config_audit "$@"
            ;;
        config_optimize)
            ai_prompt_config_optimize "$@"
            ;;
        health_report)
            ai_prompt_health_report "$@"
            ;;
        alert_analysis)
            ai_prompt_alert_analysis "$@"
            ;;
        script_review)
            ai_prompt_script_review "$@"
            ;;
        deployment_advice)
            ai_prompt_deployment_advice "$@"
            ;;
        *)
            echo "$*"
            ;;
    esac
}

# 列出所有可用模板
ai_list_templates() {
    echo "=== 系统提示词模板 ==="
    echo "  cicd, expert      - CI/CD 专家"
    echo "  log, log_analyzer - 日志分析专家"
    echo "  config, config_advisor - 配置审计专家"
    echo "  health, health_analyzer - 健康检查专家"
    echo "  alert, alert_analyzer - 告警分析专家"
    echo ""
    echo "=== 用户提示词模板 ==="
    echo "  log_analysis      - 日志分析"
    echo "  error_diagnosis   - 错误诊断"
    echo "  config_audit      - 配置审计"
    echo "  config_optimize   - 配置优化"
    echo "  health_report     - 健康报告"
    echo "  alert_analysis    - 告警分析"
    echo "  script_review     - 脚本审查"
    echo "  deployment_advice - 部署建议"
}
