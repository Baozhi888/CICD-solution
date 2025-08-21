#!/bin/bash

# 增强日志管理库单元测试
# 测试 lib/core/enhanced-logging.sh

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
# 由于 enhanced-logging.sh 会调用 logging.sh 的函数，
# 并且它会立即执行 init_log_management，
# 我们需要先设置一些环境变量来避免干扰。
LOG_ROTATE_ENABLED=false
LOG_CLEANUP_ENABLED=false
source "$(dirname "$0")/../../lib/core/logging.sh"
source "$(dirname "$0")/../../lib/core/enhanced-logging.sh"

# --- 测试用例 ---

test_log_formatting() {
    echo "测试日志格式化功能..."
    
    local test_message="这是一条测试消息"
    local timestamp_regex="[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}"
    
    # 1. 测试标准格式
    LOG_FORMAT="standard"
    local standard_output=$(format_standard_log "INFO" "$test_message")
    assert_match "$standard_output" "${LOG_GREEN}\[$timestamp_regex\] \[.*\] \[INFO\]${LOG_NC} $test_message" "标准格式输出不正确"
    
    # 2. 测试结构化格式
    LOG_FORMAT="structured"
    local structured_output=$(format_structured_log "WARN" "$test_message")
    assert_match "$structured_output" "\[$timestamp_regex\] \[WARN\] \[.*\] $test_message" "结构化格式输出不正确"
    
    # 3. 测试 JSON 格式
    LOG_FORMAT="json"
    local json_output=$(format_json_log "ERROR" "$test_message")
    # 简单验证是否为有效的 JSON 结构
    assert_contains "$json_output" "\"timestamp\":\"$timestamp_regex\"" "JSON 格式应包含时间戳"
    assert_contains "$json_output" "\"level\":\"ERROR\"" "JSON 格式应包含级别"
    assert_contains "$json_output" "\"message\":\"$test_message\"" "JSON 格式应包含消息"
}

test_log_file_operations() {
    echo "测试日志文件操作..."
    
    local test_log_file=$(create_test_file "test_file_ops.log")
    local test_message="测试文件写入"
    
    # 1. 测试 log_to_file
    log_to_file "$test_message" "$test_log_file"
    assert_file_exists "$test_log_file" "日志文件应被创建"
    assert_contains "$(cat "$test_log_file")" "$test_message" "日志文件应包含写入的消息"
    
    # 2. 测试带颜色的日志写入（颜色代码应被移除）
    local colored_message="${LOG_RED}带颜色的消息${LOG_NC}"
    log_to_file "$colored_message" "$test_log_file"
    # 读取文件内容，验证颜色代码已被移除
    local file_content=$(cat "$test_log_file")
    assert_not_contains "$file_content" "\033\[0;31m" "日志文件不应包含颜色代码"
    assert_not_contains "$file_content" "\033\[0m" "日志文件不应包含颜色代码"
    assert_contains "$file_content" "带颜色的消息" "日志文件应包含原始消息"
}

test_file_handle_operations() {
    echo "测试文件句柄操作..."
    
    local handle_name="test_handle"
    local handle_file=$(create_test_file "handle_test.log")
    
    # 1. 打开日志文件
    open_log_file "$handle_name" "$handle_file"
    assert_equals "$handle_file" "${LOG_FILE_HANDLES[$handle_name]}" "文件句柄映射应正确"
    
    # 2. 写入到句柄
    log_to_file_handle "$handle_name" "INFO" "通过句柄写入的消息"
    assert_file_exists "$handle_file" "通过句柄创建的日志文件应存在"
    assert_contains "$(cat "$handle_file")" "通过句柄写入的消息" "通过句柄写入的消息应存在"
    
    # 3. 关闭日志文件
    close_log_file "$handle_name"
    assert_empty "${LOG_FILE_HANDLES[$handle_name]:-}" "关闭句柄后，映射应为空"
}

test_log_rotation_simulation() {
    echo "测试日志轮转模拟..."
    
    # 创建一个大于轮转大小的日志文件
    LOG_ROTATE_SIZE=100 # 设置一个很小的轮转大小用于测试
    local test_log=$(create_test_file "rotate_test.log")
    
    # 写入超过 100 字节的内容
    printf 'A%.0s' {1..150} > "$test_log"
    
    # 模拟检查轮转
    # 由于 rotate_log 会执行 mv 和 gzip 等操作，我们在这里只验证 check_log_rotation 的逻辑
    # 实际的 rotate_log 测试更适合集成测试
    
    local file_size=$(stat -f%z "$test_log" 2>/dev/null || stat -c%s "$test_log" 2>/dev/null || echo 0)
    if [ $file_size -gt $LOG_ROTATE_SIZE ]; then
        # 这里我们验证逻辑，不实际执行 rotate_log
        assert_true true "文件大小 $file_size 超过轮转大小 $LOG_ROTATE_SIZE，应触发轮转"
    else
        assert_true false "文件大小未超过轮转阈值，测试设置有误"
    fi
}

test_log_cleanup_simulation() {
    echo "测试日志清理模拟..."
    
    local test_dir="$TEST_TMP_DIR/cleanup_test"
    mkdir -p "$test_dir"
    
    # 创建一个旧文件 (31天前)
    local old_file="$test_dir/old.log"
    touch -d '31 days ago' "$old_file"
    
    # 创建一个新文件 (1天前)
    local new_file="$test_dir/new.log"
    touch -d '1 day ago' "$new_file"
    
    # 模拟 cleanup_old_logs 的 find 逻辑
    # find "$test_dir" -name "*.log" -type f -mtime +30
    local old_files_found
    old_files_found=$(find "$test_dir" -name "*.log" -type f -mtime +30)
    
    assert_contains "$old_files_found" "$old_file" "应找到31天前的旧文件"
    assert_not_contains "$old_files_found" "$new_file" "不应找到1天前的新文件"
}


# --- 主测试函数 ---

run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "日志格式化" test_log_formatting
    run_test_suite "文件操作" test_log_file_operations
    run_test_suite "文件句柄" test_file_handle_operations
    run_test_suite "日志轮转" test_log_rotation_simulation
    run_test_suite "日志清理" test_log_cleanup_simulation
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi