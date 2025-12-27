#!/bin/bash

# =============================================================================
# test-utils-colors.sh - 颜色库测试
# =============================================================================
# 测试 lib/utils/colors.sh 的功能
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-framework.sh"

PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
COLORS_LIB="$PROJECT_ROOT/lib/utils/colors.sh"

# =============================================================================
# 测试: 颜色库加载
# =============================================================================

test_colors_lib_loads() {
    echo "测试: 颜色库正常加载"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    assert_equals "0" "$?" "颜色库应正常加载"
}

test_colors_defined() {
    echo "测试: 基础颜色变量已定义"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    # 测试基础颜色是否定义（值可能为空字符串如果终端不支持颜色）
    [[ -v COLOR_RED ]] && assert_equals "true" "true" "COLOR_RED 应已定义" || assert_equals "true" "false" "COLOR_RED 应已定义"
    [[ -v COLOR_GREEN ]] && assert_equals "true" "true" "COLOR_GREEN 应已定义" || assert_equals "true" "false" "COLOR_GREEN 应已定义"
    [[ -v COLOR_YELLOW ]] && assert_equals "true" "true" "COLOR_YELLOW 应已定义" || assert_equals "true" "false" "COLOR_YELLOW 应已定义"
    [[ -v COLOR_BLUE ]] && assert_equals "true" "true" "COLOR_BLUE 应已定义" || assert_equals "true" "false" "COLOR_BLUE 应已定义"
    [[ -v COLOR_NC ]] && assert_equals "true" "true" "COLOR_NC 应已定义" || assert_equals "true" "false" "COLOR_NC 应已定义"
}

test_semantic_colors_defined() {
    echo "测试: 语义化颜色别名已定义"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    [[ -v COLOR_ERROR ]] && assert_equals "true" "true" "COLOR_ERROR 应已定义" || assert_equals "true" "false" "COLOR_ERROR 应已定义"
    [[ -v COLOR_SUCCESS ]] && assert_equals "true" "true" "COLOR_SUCCESS 应已定义" || assert_equals "true" "false" "COLOR_SUCCESS 应已定义"
    [[ -v COLOR_WARNING ]] && assert_equals "true" "true" "COLOR_WARNING 应已定义" || assert_equals "true" "false" "COLOR_WARNING 应已定义"
    [[ -v COLOR_INFO ]] && assert_equals "true" "true" "COLOR_INFO 应已定义" || assert_equals "true" "false" "COLOR_INFO 应已定义"
}

test_backward_compatibility() {
    echo "测试: 向后兼容旧前缀"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    # 测试旧前缀别名
    [[ -v LOG_RED ]] && assert_equals "true" "true" "LOG_RED 别名应存在" || assert_equals "true" "false" "LOG_RED 别名应存在"
    [[ -v VAL_GREEN ]] && assert_equals "true" "true" "VAL_GREEN 别名应存在" || assert_equals "true" "false" "VAL_GREEN 别名应存在"
    [[ -v GEN_BLUE ]] && assert_equals "true" "true" "GEN_BLUE 别名应存在" || assert_equals "true" "false" "GEN_BLUE 别名应存在"
    [[ -v CFG_NC ]] && assert_equals "true" "true" "CFG_NC 别名应存在" || assert_equals "true" "false" "CFG_NC 别名应存在"
}

# =============================================================================
# 测试: 便捷输出函数
# =============================================================================

test_print_functions_exist() {
    echo "测试: 便捷输出函数存在"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    # 检查函数是否存在
    declare -f print_success >/dev/null && assert_equals "true" "true" "print_success 函数应存在" || assert_equals "true" "false" "print_success 函数应存在"
    declare -f print_error >/dev/null && assert_equals "true" "true" "print_error 函数应存在" || assert_equals "true" "false" "print_error 函数应存在"
    declare -f print_warning >/dev/null && assert_equals "true" "true" "print_warning 函数应存在" || assert_equals "true" "false" "print_warning 函数应存在"
    declare -f print_info >/dev/null && assert_equals "true" "true" "print_info 函数应存在" || assert_equals "true" "false" "print_info 函数应存在"
}

test_print_functions_output() {
    echo "测试: 便捷输出函数正常输出"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    local output

    output=$(print_success "test message" 2>&1)
    assert_contains "$output" "test message" "print_success 应输出消息"

    output=$(print_error "error message" 2>&1)
    assert_contains "$output" "error message" "print_error 应输出消息"

    output=$(print_info "info message" 2>&1)
    assert_contains "$output" "info message" "print_info 应输出消息"
}

test_print_separator() {
    echo "测试: print_separator 函数"

    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    local output
    output=$(print_separator "-" 10)

    assert_equals "----------" "$output" "print_separator 应输出正确长度的分隔线"
}

# =============================================================================
# 测试: 防止重复加载
# =============================================================================

test_no_duplicate_loading() {
    echo "测试: 防止重复加载"

    # 第一次加载
    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    # 保存 _COLORS_LOADED 值
    local first_load="${_COLORS_LOADED:-}"

    # 第二次加载
    # shellcheck source=/dev/null
    source "$COLORS_LIB"

    # 值应该相同，说明第二次没有重新执行
    assert_equals "$first_load" "${_COLORS_LOADED:-}" "重复加载应被跳过"
}

# =============================================================================
# 测试: NO_COLOR 环境变量
# =============================================================================

test_no_color_env() {
    echo "测试: NO_COLOR 环境变量禁用颜色"

    # 在子 shell 中测试
    local output
    output=$(
        export NO_COLOR=1
        unset _COLORS_LOADED
        # shellcheck source=/dev/null
        source "$COLORS_LIB"
        echo "${COLOR_RED}"
    )

    assert_equals "" "$output" "NO_COLOR=1 时颜色应为空"
}

# =============================================================================
# 运行所有测试
# =============================================================================

run_all_tests() {
    test_init

    echo -e "\n${TEST_BLUE}=== colors.sh 颜色库测试 ===${TEST_NC}\n"

    run_test_suite "颜色库加载测试" test_colors_lib_loads
    run_test_suite "基础颜色定义测试" test_colors_defined
    run_test_suite "语义化颜色测试" test_semantic_colors_defined
    run_test_suite "向后兼容测试" test_backward_compatibility
    run_test_suite "便捷函数存在测试" test_print_functions_exist
    run_test_suite "便捷函数输出测试" test_print_functions_output
    run_test_suite "分隔线函数测试" test_print_separator
    run_test_suite "防止重复加载测试" test_no_duplicate_loading
    run_test_suite "NO_COLOR 环境变量测试" test_no_color_env

    print_test_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
