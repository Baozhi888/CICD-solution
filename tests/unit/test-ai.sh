#!/bin/bash

# AI 模块单元测试
# 测试 lib/ai/ 中的 AI 功能函数

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
source "$(dirname "$0")/../../lib/ai/ai-core.sh"
source "$(dirname "$0")/../../lib/ai/prompt-templates.sh"

# =============================================================================
# AI 核心模块测试
# =============================================================================

test_ai_core_loading() {
    echo "测试 AI 核心模块加载..."

    # 测试模块版本
    assert_not_empty "${AI_MODULE_VERSION}" "AI 模块版本应该定义"

    # 测试默认配置
    assert_not_empty "${AI_PROVIDER}" "AI 提供商应该有默认值"
    assert_not_empty "${AI_CLAUDE_MODEL}" "Claude 模型应该有默认值"
    assert_not_empty "${AI_OPENAI_MODEL}" "OpenAI 模型应该有默认值"
}

test_ai_is_enabled() {
    echo "测试 AI 启用状态检查..."

    # 默认应该禁用
    AI_ENABLED="false"
    assert_command_fails "ai_is_enabled" "AI 默认应该禁用"

    # 设置为启用
    AI_ENABLED="true"
    assert_command_succeeds "ai_is_enabled" "AI 设置为 true 时应该启用"

    # 恢复默认
    AI_ENABLED="false"
}

test_ai_get_config() {
    echo "测试 AI 配置获取..."

    # 测试获取各种配置
    local provider
    provider=$(ai_get_config "provider")
    assert_not_empty "${provider}" "应该能获取 provider 配置"

    local model
    model=$(ai_get_config "claude.model")
    assert_not_empty "${model}" "应该能获取 claude.model 配置"

    # 测试默认值
    local unknown
    unknown=$(ai_get_config "unknown.key" "default_value")
    assert_equals "default_value" "${unknown}" "未知配置应该返回默认值"
}

test_ai_set_config() {
    echo "测试 AI 配置设置..."

    # 保存原值
    local original_provider="${AI_PROVIDER}"

    # 设置新值
    ai_set_config "provider" "openai"
    assert_equals "openai" "${AI_PROVIDER}" "应该能设置 provider 配置"

    # 恢复原值
    ai_set_config "provider" "${original_provider}"
}

test_ai_cache_functions() {
    echo "测试 AI 缓存功能..."

    # 启用缓存
    AI_CACHE_ENABLED="true"
    AI_CACHE_DIR="/tmp/aicd-test-cache"
    AI_CACHE_TTL="60"

    # 清理测试目录
    rm -rf "${AI_CACHE_DIR}"

    # 测试缓存设置
    ai_cache_set "test_key" "test_value"
    assert_file_exists "${AI_CACHE_DIR}/test_key.cache" "缓存文件应该创建"

    # 测试缓存获取
    local cached_value
    cached_value=$(ai_cache_get "test_key")
    assert_equals "test_value" "${cached_value}" "应该能获取缓存值"

    # 测试缓存未命中
    local missing_value
    if ! missing_value=$(ai_cache_get "nonexistent_key" 2>/dev/null); then
        echo "缓存未命中测试通过"
    else
        assert_fail "不存在的缓存键应该返回失败"
    fi

    # 清理
    rm -rf "${AI_CACHE_DIR}"
}

test_ai_status() {
    echo "测试 AI 状态显示..."

    local status_output
    status_output=$(ai_status)

    assert_contains "${status_output}" "AI 模块状态" "状态输出应该包含标题"
    assert_contains "${status_output}" "版本" "状态输出应该包含版本"
    assert_contains "${status_output}" "启用状态" "状态输出应该包含启用状态"
}

# =============================================================================
# 提示词模板测试
# =============================================================================

test_prompt_templates_system() {
    echo "测试系统提示词模板..."

    # 测试获取不同类型的系统提示词
    local cicd_prompt
    cicd_prompt=$(ai_get_system_prompt "cicd")
    assert_not_empty "${cicd_prompt}" "应该能获取 CICD 系统提示词"

    local log_prompt
    log_prompt=$(ai_get_system_prompt "log_analyzer")
    assert_not_empty "${log_prompt}" "应该能获取日志分析系统提示词"

    local config_prompt
    config_prompt=$(ai_get_system_prompt "config_advisor")
    assert_not_empty "${config_prompt}" "应该能获取配置顾问系统提示词"

    # 测试默认值
    local unknown_prompt
    unknown_prompt=$(ai_get_system_prompt "unknown_type")
    assert_not_empty "${unknown_prompt}" "未知类型应该返回默认提示词"
}

test_prompt_templates_user() {
    echo "测试用户提示词模板..."

    # 测试日志分析模板
    local log_prompt
    log_prompt=$(ai_prompt_log_analysis "ERROR: test error")
    assert_contains "${log_prompt}" "日志内容" "日志分析模板应该包含日志内容标签"
    assert_contains "${log_prompt}" "ERROR: test error" "日志分析模板应该包含实际日志"

    # 测试配置审计模板
    local config_prompt
    config_prompt=$(ai_prompt_config_audit "key: value" "YAML")
    assert_contains "${config_prompt}" "配置内容" "配置审计模板应该包含配置内容标签"
    assert_contains "${config_prompt}" "YAML" "配置审计模板应该包含配置类型"

    # 测试健康报告模板
    local health_prompt
    health_prompt=$(ai_prompt_health_report "CPU: 50%")
    assert_contains "${health_prompt}" "系统指标" "健康报告模板应该包含指标标签"
}

test_list_templates() {
    echo "测试模板列表..."

    local templates_output
    templates_output=$(ai_list_templates)

    assert_contains "${templates_output}" "系统提示词模板" "应该列出系统提示词模板"
    assert_contains "${templates_output}" "用户提示词模板" "应该列出用户提示词模板"
    assert_contains "${templates_output}" "log_analysis" "应该包含日志分析模板"
    assert_contains "${templates_output}" "config_audit" "应该包含配置审计模板"
}

# =============================================================================
# 依赖检查测试
# =============================================================================

test_ai_check_dependencies() {
    echo "测试依赖检查..."

    # 依赖检查应该通过（假设 curl 和 jq 已安装）
    if command -v curl &>/dev/null && command -v jq &>/dev/null; then
        assert_command_succeeds "ai_check_dependencies" "依赖检查应该通过"
    else
        echo "跳过依赖检查测试（缺少 curl 或 jq）"
    fi
}

# =============================================================================
# 主测试函数
# =============================================================================

run_all_tests() {
    test_init

    # 运行所有测试套件
    run_test_suite "AI 核心模块加载" test_ai_core_loading
    run_test_suite "AI 启用状态" test_ai_is_enabled
    run_test_suite "AI 配置获取" test_ai_get_config
    run_test_suite "AI 配置设置" test_ai_set_config
    run_test_suite "AI 缓存功能" test_ai_cache_functions
    run_test_suite "AI 状态显示" test_ai_status
    run_test_suite "系统提示词模板" test_prompt_templates_system
    run_test_suite "用户提示词模板" test_prompt_templates_user
    run_test_suite "模板列表" test_list_templates
    run_test_suite "依赖检查" test_ai_check_dependencies

    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
