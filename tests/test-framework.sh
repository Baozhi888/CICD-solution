#!/bin/bash

# Shell 脚本单元测试框架
# 提供简单的断言和测试运行功能

# 测试统计
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
FAILED_TEST_NAMES=()

# 颜色输出
TEST_RED='\033[0;31m'
TEST_GREEN='\033[0;32m'
TEST_YELLOW='\033[1;33m'
TEST_BLUE='\033[0;34m'
TEST_NC='\033[0m'

# 测试设置
TEST_TMP_DIR="/tmp/cicd-tests"
TEST_VERBOSE=${TEST_VERBOSE:-false}

# 初始化测试环境
test_init() {
    mkdir -p "$TEST_TMP_DIR"
    TOTAL_TESTS=0
    PASSED_TESTS=0
    FAILED_TESTS=0
    FAILED_TEST_NAMES=()
    
    if [ "$TEST_VERBOSE" = "true" ]; then
        echo -e "${TEST_BLUE}=== 开始测试 ===${TEST_NC}"
    fi
}

# 清理测试环境
test_cleanup() {
    if [ -d "$TEST_TMP_DIR" ]; then
        rm -rf "$TEST_TMP_DIR"
    fi
}

# 断言函数
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"断言失败"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$expected" = "$actual" ]; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}期望:${TEST_NC} '$expected'"
        echo -e "    ${TEST_YELLOW}实际:${TEST_NC} '$actual'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 断言不等于
assert_not_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-"断言失败"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ "$expected" != "$actual" ]; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}不应该等于:${TEST_NC} '$expected'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 断言包含
assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-"断言失败"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}期望包含:${TEST_NC} '$needle'"
        echo -e "    ${TEST_YELLOW}实际字符串:${TEST_NC} '$haystack'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 断言文件存在
assert_file_exists() {
    local filepath="$1"
    local message="${2:-"文件应该存在"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [ -f "$filepath" ]; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}文件不存在:${TEST_NC} '$filepath'"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 断言命令成功
assert_command_succeeds() {
    local command="$1"
    local message="${2:-"命令应该成功执行"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if eval "$command" >/dev/null 2>&1; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}失败的命令:${TEST_NC} $command"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 断言命令失败
assert_command_fails() {
    local command="$1"
    local message="${2:-"命令应该失败"}"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if ! eval "$command" >/dev/null 2>&1; then
        if [ "$TEST_VERBOSE" = "true" ]; then
            echo -e "  ${TEST_GREEN}✓${TEST_NC} $message"
        fi
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "  ${TEST_RED}✗${TEST_NC} $message"
        echo -e "    ${TEST_YELLOW}命令意外成功:${TEST_NC} $command"
        FAILED_TESTS=$((FAILED_TESTS + 1))
        FAILED_TEST_NAMES+=("$message")
        return 1
    fi
}

# 运行测试套件
run_test_suite() {
    local suite_name="$1"
    local suite_function="$2"
    
    echo -e "\n${TEST_BLUE}=== 运行测试套件: $suite_name ===${TEST_NC}"
    
    # 保存当前测试统计
    local saved_total=$TOTAL_TESTS
    local saved_passed=$PASSED_TESTS
    local saved_failed=$FAILED_TESTS
    
    # 运行测试函数
    $suite_function
    
    # 计算本套件的结果
    local suite_total=$((TOTAL_TESTS - saved_total))
    local suite_passed=$((PASSED_TESTS - saved_passed))
    local suite_failed=$((FAILED_TESTS - saved_failed))
    
    echo -e "${TEST_BLUE}套件结果:${TEST_NC} $suite_passed/$suite_total 通过"
    
    if [ $suite_failed -gt 0 ]; then
        return 1
    fi
}

# 打印测试摘要
print_test_summary() {
    echo -e "\n${TEST_BLUE}=== 测试摘要 ===${TEST_NC}"
    echo -e "总测试数: $TOTAL_TESTS"
    echo -e "${TEST_GREEN}通过: $PASSED_TESTS${TEST_NC}"
    echo -e "${TEST_RED}失败: $FAILED_TESTS${TEST_NC}"
    
    if [ $FAILED_TESTS -gt 0 ]; then
        echo -e "\n${TEST_YELLOW}失败的测试:${TEST_NC}"
        for failed_test in "${FAILED_TEST_NAMES[@]}"; do
            echo -e "  - $failed_test"
        done
        echo -e "\n${TEST_RED}=== 测试失败 ===${TEST_NC}"
        return 1
    else
        echo -e "\n${TEST_GREEN}=== 所有测试通过 ===${TEST_NC}"
        return 0
    fi
}

# 创建测试临时文件
create_test_file() {
    local filename="$1"
    local content="$2"
    
    echo "$content" > "$TEST_TMP_DIR/$filename"
    echo "$TEST_TMP_DIR/$filename"
}

# 模拟命令
mock_command() {
    local command_name="$1"
    local mock_script="$2"
    
    # 创建临时 mock 脚本
    local mock_path="$TEST_TMP_DIR/mock-$command_name"
    echo "#!/bin/bash" > "$mock_path"
    echo "$mock_script" >> "$mock_path"
    chmod +x "$mock_path"
    
    # 修改 PATH 以使用 mock
    export PATH="$TEST_TMP_DIR:$PATH"
}

# 设置测试陷阱
trap 'test_cleanup; exit 1' INT TERM

# 在脚本正常退出时清理
trap 'test_cleanup' EXIT

# 导出测试函数
export -f assert_equals assert_not_equals assert_contains
export -f assert_file_exists assert_command_succeeds assert_command_fails
export -f run_test_suite print_test_summary
export -f create_test_file mock_command
export TEST_TMP_DIR TEST_VERBOSE