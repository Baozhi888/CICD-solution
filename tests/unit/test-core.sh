#!/bin/bash

# 核心库单元测试
# 测试 lib/core/ 中的核心函数

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
source "$(dirname "$0")/../../lib/core/utils.sh"
source "$(dirname "$0")/../../lib/core/validation.sh"

# 测试用例
test_utils_functions() {
    echo "测试工具函数..."
    
    # 测试 trim 函数
    local test_string="  hello world  "
    local trimmed=$(trim "$test_string")
    assert_equals "hello world" "$trimmed" "trim 函数应该去除首尾空格"
    
    # 测试 is_empty 函数
    assert_command_succeeds "is_empty ''" "is_empty 应该识别空字符串"
    assert_command_fails "is_empty 'not empty'" "is_empty 应该拒绝非空字符串"
    
    # 测试 to_lower 函数
    local upper="HELLO WORLD"
    local lower=$(to_lower "$upper")
    assert_equals "hello world" "$lower" "to_lower 应该转换为小写"
}

test_validation_functions() {
    echo "测试验证函数..."
    
    # 测试 is_number 函数
    assert_command_succeeds "is_number '123'" "is_number 应该接受数字"
    assert_command_fails "is_number 'abc'" "is_number 应该拒绝非数字"
    
    # 测试 is_email 函数
    assert_command_succeeds "is_email 'test@example.com'" "is_email 应该接受有效邮箱"
    assert_command_fails "is_email 'invalid-email'" "is_email 应该拒绝无效邮箱"
    
    # 测试 is_url 函数
    assert_command_succeeds "is_url 'https://example.com'" "is_url 应该接受有效URL"
    assert_command_fails "is_url 'not-a-url'" "is_url 应该拒绝无效URL"
}

test_error_handling() {
    echo "测试错误处理..."
    
    # 测试错误处理函数
    local error_msg="测试错误"
    local log_file=$(create_test_file "error.log" "")
    
    # 模拟错误日志记录
    handle_error "$error_msg" "$log_file"
    assert_file_exists "$log_file" "错误日志文件应该存在"
    assert_contains "$(cat "$log_file")" "$error_msg" "错误日志应该包含错误消息"
}

# 主测试函数
run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "工具函数" test_utils_functions
    run_test_suite "验证函数" test_validation_functions
    run_test_suite "错误处理" test_error_handling
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi