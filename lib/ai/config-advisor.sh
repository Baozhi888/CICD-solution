#!/bin/bash

# =============================================================================
# AI 配置顾问
# =============================================================================
# 使用 AI 分析配置文件，提供安全检查、性能优化和最佳实践建议
# =============================================================================

# 防止重复加载
if [ -n "${_AI_CONFIG_ADVISOR_LOADED:-}" ]; then
    return 0
fi
_AI_CONFIG_ADVISOR_LOADED=1

# 加载依赖模块
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/ai-core.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/api-client.sh" 2>/dev/null || true
source "${SCRIPT_DIR}/prompt-templates.sh" 2>/dev/null || true

# 配置顾问配置
CONFIG_ADVISOR_MAX_SIZE="${CONFIG_ADVISOR_MAX_SIZE:-30000}"

# 敏感字段列表
CONFIG_SENSITIVE_FIELDS=(
    "password"
    "passwd"
    "pwd"
    "secret"
    "token"
    "api_key"
    "apikey"
    "api-key"
    "private_key"
    "privatekey"
    "private-key"
    "access_key"
    "secret_key"
    "auth_token"
    "credentials"
)

# =============================================================================
# 配置读取和预处理
# =============================================================================

# 读取配置文件
_config_read_file() {
    local config_file="$1"

    if [ ! -f "${config_file}" ]; then
        ai_log_error "配置文件不存在: ${config_file}"
        return 1
    fi

    cat "${config_file}" 2>/dev/null
}

# 检测配置文件类型
_config_detect_type() {
    local config_file="$1"

    case "${config_file##*.}" in
        yaml|yml)
            echo "YAML"
            ;;
        json)
            echo "JSON"
            ;;
        toml)
            echo "TOML"
            ;;
        ini|conf|cfg)
            echo "INI"
            ;;
        env)
            echo "ENV"
            ;;
        tf)
            echo "Terraform"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# 脱敏配置中的敏感信息
_config_redact_sensitive() {
    local config_content="$1"
    local result="${config_content}"

    for field in "${CONFIG_SENSITIVE_FIELDS[@]}"; do
        # 处理 YAML/JSON 格式
        result=$(echo "${result}" | sed -E \
            -e "s/(${field}[[:space:]]*:[[:space:]]*)[^[:space:]\",}]+/\1***REDACTED***/gi" \
            -e "s/(\"${field}\"[[:space:]]*:[[:space:]]*\")[^\"]+\"/\1***REDACTED***\"/gi" \
            -e "s/(${field}[[:space:]]*=[[:space:]]*)[^[:space:]\",]+/\1***REDACTED***/gi")
    done

    echo "${result}"
}

# 截断配置内容
_config_truncate() {
    local config_content="$1"
    local max_size="${2:-${CONFIG_ADVISOR_MAX_SIZE}}"

    if [ ${#config_content} -gt ${max_size} ]; then
        ai_log_warn "配置内容过长，已截断至 ${max_size} 字符"
        echo "${config_content:0:${max_size}}

... (配置已截断)"
    else
        echo "${config_content}"
    fi
}

# =============================================================================
# 配置审计功能
# =============================================================================

# 审计配置文件
# 用法: ai_audit_config <config_file> [focus_areas]
ai_audit_config() {
    local config_file="$1"
    local focus_areas="${2:-security,performance,best-practices}"

    if [ -z "${config_file}" ]; then
        ai_log_error "请指定配置文件"
        return 1
    fi

    if [ ! -f "${config_file}" ]; then
        ai_log_error "配置文件不存在: ${config_file}"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "审计配置文件: ${config_file}"

    # 读取配置
    local config_content
    config_content=$(_config_read_file "${config_file}")

    if [ -z "${config_content}" ]; then
        ai_log_warn "配置文件为空"
        return 0
    fi

    # 检测配置类型
    local config_type
    config_type=$(_config_detect_type "${config_file}")

    # 预处理
    config_content=$(_config_truncate "${config_content}")
    config_content=$(_config_redact_sensitive "${config_content}")

    # 生成提示词
    local system_prompt
    system_prompt=$(ai_get_system_prompt "config_advisor")
    local user_prompt
    user_prompt=$(ai_prompt_config_audit "${config_content}" "${config_type}" "${focus_areas}")

    # 调用 AI API
    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        ai_log_error "配置审计失败"
        return 1
    fi
}

# 安全检查
# 用法: ai_check_security <config_file>
ai_check_security() {
    local config_file="$1"

    if [ -z "${config_file}" ]; then
        ai_log_error "请指定配置文件"
        return 1
    fi

    ai_log_info "执行安全检查: ${config_file}"

    # 首先执行本地安全检查
    local local_issues=()

    if [ -f "${config_file}" ]; then
        local config_content
        config_content=$(_config_read_file "${config_file}")

        # 检查明文密码
        for field in "${CONFIG_SENSITIVE_FIELDS[@]}"; do
            if echo "${config_content}" | grep -qE -i "${field}[[:space:]]*[:=][[:space:]]*[^$\{\}][^[:space:]\",}]+" 2>/dev/null; then
                local_issues+=("可能存在明文 ${field}")
            fi
        done

        # 检查不安全的默认值
        if echo "${config_content}" | grep -qE -i "(password|secret)[[:space:]]*[:=][[:space:]]*(admin|password|123456|root)" 2>/dev/null; then
            local_issues+=("发现不安全的默认密码")
        fi

        # 检查开放的端口配置
        if echo "${config_content}" | grep -qE "0\.0\.0\.0" 2>/dev/null; then
            local_issues+=("发现绑定到 0.0.0.0 的配置")
        fi

        # 检查 SSL/TLS 配置
        if echo "${config_content}" | grep -qE -i "(ssl|tls)[[:space:]]*[:=][[:space:]]*(false|disabled|off)" 2>/dev/null; then
            local_issues+=("SSL/TLS 可能被禁用")
        fi
    fi

    echo "=== 本地安全检查结果 ==="
    if [ ${#local_issues[@]} -gt 0 ]; then
        echo "发现 ${#local_issues[@]} 个潜在安全问题:"
        for issue in "${local_issues[@]}"; do
            echo "  - ${issue}"
        done
    else
        echo "未发现明显的安全问题"
    fi
    echo ""

    # 如果 AI 启用，进行深度分析
    if ai_is_enabled; then
        echo "=== AI 深度安全分析 ==="
        ai_audit_config "${config_file}" "security"
    fi
}

# 配置优化建议
# 用法: ai_optimize_config <config_file> [optimization_goal]
ai_optimize_config() {
    local config_file="$1"
    local optimization_goal="${2:-performance}"

    if [ -z "${config_file}" ]; then
        ai_log_error "请指定配置文件"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "生成配置优化建议: ${config_file} (目标: ${optimization_goal})"

    # 读取配置
    local config_content
    config_content=$(_config_read_file "${config_file}")

    if [ -z "${config_content}" ]; then
        ai_log_warn "配置文件为空"
        return 0
    fi

    # 预处理
    config_content=$(_config_truncate "${config_content}")
    config_content=$(_config_redact_sensitive "${config_content}")

    # 生成提示词
    local system_prompt
    system_prompt=$(ai_get_system_prompt "config_advisor")
    local user_prompt
    user_prompt=$(ai_prompt_config_optimize "${config_content}" "${optimization_goal}")

    # 调用 AI API
    local response
    response=$(ai_api_call "${system_prompt}" "${user_prompt}")

    if [ $? -eq 0 ]; then
        echo "${response}"
        return 0
    else
        ai_log_error "生成优化建议失败"
        return 1
    fi
}

# YAML 验证
# 用法: ai_validate_yaml <yaml_file>
ai_validate_yaml() {
    local yaml_file="$1"

    if [ -z "${yaml_file}" ]; then
        ai_log_error "请指定 YAML 文件"
        return 1
    fi

    if [ ! -f "${yaml_file}" ]; then
        ai_log_error "文件不存在: ${yaml_file}"
        return 1
    fi

    ai_log_info "验证 YAML 文件: ${yaml_file}"

    local validation_result="=== YAML 验证结果 ===\n"
    local has_errors=false

    # 使用 yq 验证 (如果可用)
    if command -v yq &>/dev/null; then
        if yq eval '.' "${yaml_file}" >/dev/null 2>&1; then
            validation_result+="语法检查: 通过\n"
        else
            validation_result+="语法检查: 失败\n"
            validation_result+="错误: $(yq eval '.' "${yaml_file}" 2>&1)\n"
            has_errors=true
        fi
    else
        validation_result+="语法检查: 跳过 (未安装 yq)\n"
    fi

    # 使用 python 验证 (备选)
    if command -v python3 &>/dev/null && ! ${has_errors}; then
        if python3 -c "import yaml; yaml.safe_load(open('${yaml_file}'))" 2>/dev/null; then
            validation_result+="Python YAML 解析: 通过\n"
        else
            validation_result+="Python YAML 解析: 失败\n"
            has_errors=true
        fi
    fi

    echo -e "${validation_result}"

    # 如果 AI 启用且无语法错误，进行语义检查
    if ai_is_enabled && ! ${has_errors}; then
        echo "=== AI 语义检查 ==="

        local config_content
        config_content=$(_config_read_file "${yaml_file}")
        config_content=$(_config_redact_sensitive "${config_content}")

        local system_prompt
        system_prompt=$(ai_get_system_prompt "config_advisor")
        local user_prompt="请检查以下 YAML 配置的语义正确性，包括：
1. 配置项命名是否合理
2. 值的类型是否正确
3. 必需字段是否缺失
4. 配置结构是否符合最佳实践

配置内容：
\`\`\`yaml
${config_content}
\`\`\`"

        ai_api_call "${system_prompt}" "${user_prompt}"
    fi

    if ${has_errors}; then
        return 1
    fi
    return 0
}

# =============================================================================
# 配置比较功能
# =============================================================================

# 比较两个配置文件
# 用法: ai_compare_configs <config1> <config2>
ai_compare_configs() {
    local config1="$1"
    local config2="$2"

    if [ -z "${config1}" ] || [ -z "${config2}" ]; then
        ai_log_error "请指定两个配置文件进行比较"
        return 1
    fi

    if [ ! -f "${config1}" ] || [ ! -f "${config2}" ]; then
        ai_log_error "配置文件不存在"
        return 1
    fi

    ai_log_info "比较配置: ${config1} vs ${config2}"

    # 读取配置
    local content1 content2
    content1=$(_config_read_file "${config1}")
    content2=$(_config_read_file "${config2}")

    # 本地 diff
    echo "=== 配置差异 (diff) ==="
    diff -u "${config1}" "${config2}" 2>/dev/null || true
    echo ""

    # 如果 AI 启用，进行语义分析
    if ai_is_enabled; then
        echo "=== AI 差异分析 ==="

        content1=$(_config_redact_sensitive "${content1}")
        content2=$(_config_redact_sensitive "${content2}")

        local system_prompt
        system_prompt=$(ai_get_system_prompt "config_advisor")
        local user_prompt="请分析以下两个配置文件的差异，说明：
1. 主要的配置变更
2. 变更的影响
3. 潜在的风险
4. 建议的改进

配置文件 1 (${config1}):
\`\`\`
${content1}
\`\`\`

配置文件 2 (${config2}):
\`\`\`
${content2}
\`\`\`"

        ai_api_call "${system_prompt}" "${user_prompt}"
    fi
}

# =============================================================================
# 配置模板生成
# =============================================================================

# 生成配置模板建议
# 用法: ai_suggest_config <project_type> [requirements]
ai_suggest_config() {
    local project_type="$1"
    local requirements="${2:-}"

    if [ -z "${project_type}" ]; then
        ai_log_error "请指定项目类型 (如: nodejs, python, go, java)"
        return 1
    fi

    if ! ai_is_enabled; then
        ai_log_error "AI 功能未启用"
        return 1
    fi

    ai_log_info "生成 ${project_type} 项目配置建议..."

    local system_prompt
    system_prompt=$(ai_get_system_prompt "config_advisor")
    local user_prompt="请为 ${project_type} 项目生成推荐的配置模板，包括：
1. CI/CD 配置 (GitHub Actions)
2. Docker 配置 (Dockerfile + docker-compose)
3. 环境配置 (.env 示例)
4. 日志配置
5. 安全配置建议

${requirements:+额外需求: ${requirements}

}请提供完整的配置文件示例和说明。"

    ai_api_call "${system_prompt}" "${user_prompt}"
}
