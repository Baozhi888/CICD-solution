#!/bin/bash

# 日志记录库单元测试
# 测试 lib/core/logging.sh

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
source "$(dirname "$0")/../../lib/core/logging.sh"

# --- 测试用例 ---

test_log_levels() {
    echo "测试日志级别控制..."
    
    local log_file=$(create_test_file "test_levels.log")
    DEFAULT_LOG_FILE="$log_file"

    # 1. 测试默认 INFO 级别
    # 此时 LOG_LEVEL 未设置，应默认为 1 (INFO)
    log_debug "这是debug信息"
    log_info "这是info信息"
    log_warn "这是warn信息"
    
    assert_not_contains "$(cat "$log_file")" "DEBUG" "默认INFO级别不应记录DEBUG日志"
    assert_contains "$(cat "$log_file")" "INFO" "默认INFO级别应记录INFO日志"
    assert_contains "$(cat "$log_file")" "WARN" "默认INFO级别应记录WARN日志"
    
    # 清空日志文件
    > "$log_file"

    # 2. 测试设置为 WARN 级别
    set_log_level "warn"
    log_info "这是info信息"
    log_warn "这是warn信息"
    log_error "这是error信息"

    assert_not_contains "$(cat "$log_file")" "INFO" "WARN级别不应记录INFO日志"
    assert_contains "$(cat "$log_file")" "WARN" "WARN级别应记录WARN日志"
    assert_contains "$(cat "$log_file")" "ERROR" "WARN级别应记录ERROR日志"
}

test_log_to_file() {
    echo "测试日志到文件功能..."
    
    local log_file=$(create_test_file "test_file_logging.log")
    DEFAULT_LOG_FILE="$log_file"
    
    # 确保日志级别足够低以记录所有信息
    set_log_level "debug"
    
    local test_message="这是一条要写入文件的测试消息"
    log_info "$test_message"
    
    assert_file_exists "$log_file" "日志文件应该被创建"
    assert_contains "$(cat "$log_file")" "$test_message" "日志文件应包含测试消息"
    
    # 验证日志格式 [TIMESTAMP] [MODULE] [LEVEL] MESSAGE
    # 例如: 2023-10-27 10:30:00 [CI/CD] [INFO] 这是一条...
    local log_content=$(cat "$log_file")
    assert_match "$log_content" "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \[.*\] \[INFO\] $test_message" "日志文件中的格式不正确"
}

test_log_module_name() {
    echo "测试设置日志模块名称..."
    
    local log_file=$(create_test_file "test_module.log")
    DEFAULT_LOG_FILE="$log_file"
    set_log_level "info"
    
    local custom_module="MyAwesomeModule"
    set_log_module "$custom_module"
    
    log_info "测试自定义模块名"
    
    assert_contains "$(cat "$log_file")" "[$custom_module]" "日志应包含自定义的模块名称"
    
    # 恢复默认模块名以避免影响其他测试
    set_log_module "CI/CD"
}

test_invalid_log_level() {
    echo "测试无效的日志级别..."
    
    # 捕获标准错误输出
    local stderr_output
    stderr_output=$(set_log_level "invalid_level" 2>&1)
    
    assert_contains "$stderr_output" "未知的日志级别: invalid_level" "设置无效日志级别时应有警告"
}


# --- 主测试函数 ---

run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "日志级别" test_log_levels
    run_test_suite "文件日志" test_log_to_file
    run_test_suite "模块名称" test_log_module_name
    run_test_suite "无效级别" test_invalid_log_level
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
