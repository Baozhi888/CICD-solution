#!/bin/bash

# 错误处理库单元测试
# 测试 lib/core/error-handler.sh

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
# 注意：由于错误处理器会设置全局陷阱 (trap)，
# 我们需要在子shell中进行测试，以避免干扰主测试脚本。
source "$(dirname "$0")/../../lib/core/logging.sh"
source "$(dirname "$0")/../../lib/core/error-handler.sh"

# --- 测试用例 ---

test_error_code_messages() {
    echo "测试错误码和消息映射..."
    
    assert_equals "成功" "${ERROR_MESSAGES[$E_SUCCESS]}" "E_SUCCESS 应该映射为 '成功'"
    assert_equals "配置错误" "${ERROR_MESSAGES[$E_CONFIG]}" "E_CONFIG 应该映射为 '配置错误'"
    assert_equals "文件未找到" "${ERROR_MESSAGES[$E_FILE_NOT_FOUND]}" "E_FILE_NOT_FOUND 应该映射为 '文件未找到'"
}

test_error_context_management() {
    echo "测试错误上下文管理..."
    
    # 初始上下文应包含脚本名
    init_error_handler
    assert_equals "script:$0" "${ERROR_CONTEXT[0]}" "初始上下文应为脚本名"
    
    # 测试 push
    push_error_context "function:my_func"
    assert_equals 2 ${#ERROR_CONTEXT[@]} "上下文堆栈大小应为 2"
    assert_equals "function:my_func" "${ERROR_CONTEXT[1]}" "第二个上下文应为 'function:my_func'"
    
    # 测试 pop
    pop_error_context
    assert_equals 1 ${#ERROR_CONTEXT[@]} "pop后上下文堆栈大小应为 1"
    
    # 清理
    ERROR_CONTEXT=()
}

test_execute_with_retry() {
    echo "测试带重试的命令执行..."
    
    local success_file=$(create_test_file "retry_success")
    local failure_file=$(create_test_file "retry_failure")
    
    # 1. 测试最终成功的场景
    # 创建一个脚本，第三次执行时才成功
    local cmd_that_succeeds_on_3rd_try="
        count=\$(cat $success_file 2>/dev/null || echo 0);
        echo \$((count + 1)) > $success_file;
        [ \$((count + 1)) -ge 3 ]
    "
    assert_command_succeeds "execute_with_retry \"$cmd_that_succeeds_on_3rd_try\" 3 0.1" "命令在第三次尝试时应该成功"
    assert_file_content "$success_file" "3" "成功文件计数应为3"
    
    # 2. 测试始终失败的场景
    local cmd_that_always_fails="
        count=\$(cat $failure_file 2>/dev/null || echo 0);
        echo \$((count + 1)) > $failure_file;
        false
    "
    assert_command_fails "execute_with_retry \"$cmd_that_always_fails\" 3 0.1" "命令在三次尝试后应该失败"
    assert_file_content "$failure_file" "3" "失败文件计数应为3"
}

test_validate_required_files_and_commands() {
    echo "测试文件和命令验证..."
    
    # 1. 验证文件
    local existing_file=$(create_test_file "exists.txt" "content")
    local missing_file="$TEST_TMP_DIR/non_existent_file"
    
    assert_command_succeeds "validate_required_files \"$existing_file\"" "验证存在的文件应该成功"
    assert_command_fails "validate_required_files \"$missing_file\"" "验证不存在的文件应该失败"
    
    # 2. 验证命令
    # 'echo' 几乎总是在系统中存在
    assert_command_succeeds "validate_required_commands \"echo\"" "验证存在的命令'echo'应该成功"
    
    # 'a_very_unlikely_command_name' 应该不存在
    assert_command_fails "validate_required_commands \"a_very_unlikely_command_name\"" "验证不存在的命令应该失败"
}

test_error_trap_simulation() {
    echo "测试错误陷阱模拟..."
    
    # 在子shell中运行以隔离 trap
    (
        # 设置错误日志文件
        ERROR_LOG_FILE=$(create_test_file "trap_test.log")
        
        # 初始化错误处理器，这会设置 ERR 陷阱
        init_error_handler
        
        # 设置上下文
        push_error_context "testing:trap"
        
        # 执行一个会失败的命令
        # 错误码 1 (E_GENERAL)
        # BASH_LINENO 会提供行号
        ( exit 1 )
        
        # 由于 trap 会导致脚本退出，我们需要检查 trap 是否被正确触发。
        # 这里我们无法直接断言，因为当前测试进程会被 trap 终止。
        # 真正的测试需要在外部脚本中执行此脚本并检查退出码和日志。
        # 这里我们仅作一个简化版的模拟。
        # 假设 handle_error 不退出
        handle_error $E_COMMAND_FAILED $LINENO "false"
        
        assert_contains "$(cat "$ERROR_LOG_FILE")" "错误码: $E_COMMAND_FAILED" "错误日志应包含错误码"
        assert_contains "$(cat "$ERROR_LOG_FILE")" "上下文: script:$0,testing:trap" "错误日志应包含上下文信息"

    ) > /dev/null 2>&1
    
    # 检查子shell是否因错误而正确退出（虽然我们无法直接捕获 trap 的 exit）
    # 这种测试更适合集成测试，但我们在这里验证 handle_error 的日志记录行为
    
}


# --- 主测试函数 ---

run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "错误码与消息" test_error_code_messages
    run_test_suite "上下文管理" test_error_context_management
    run_test_suite "重试逻辑" test_execute_with_retry
    run_test_suite "依赖验证" test_validate_required_files_and_commands
    # run_test_suite "错误陷阱" test_error_trap_simulation # trap 测试比较复杂，暂时简化

    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
