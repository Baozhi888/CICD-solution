#!/bin/bash

# 测试运行器
# 运行所有单元测试和集成测试

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色输出
RUNNER_GREEN='\033[0;32m'
RUNNER_RED='\033[0;31m'
RUNNER_YELLOW='\033[1;33m'
RUNNER_BLUE='\033[0;34m'
RUNNER_NC='\033[0m'

# 测试配置
TEST_VERBOSE=${TEST_VERBOSE:-false}
TEST_COVERAGE=${TEST_COVERAGE:-false}
TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR:-test-results}"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

CI/CD 测试运行器

选项:
  -v, --verbose      详细输出
  -c, --coverage     生成覆盖率报告
  -u, --unit-only    只运行单元测试
  -i, --int-only     只运行集成测试
  -o, --output DIR   输出目录 [默认: test-results]
  -h, --help         显示此帮助信息

环境变量:
  TEST_VERBOSE       详细输出模式
  TEST_COVERAGE      生成覆盖率报告
  TEST_OUTPUT_DIR    输出目录
EOF
}

# 解析命令行参数
UNIT_TESTS=true
INTEGRATION_TESTS=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            TEST_VERBOSE=true
            export TEST_VERBOSE=true
            shift
            ;;
        -c|--coverage)
            TEST_COVERAGE=true
            shift
            ;;
        -u|--unit-only)
            INTEGRATION_TESTS=false
            shift
            ;;
        -i|--int-only)
            UNIT_TESTS=false
            shift
            ;;
        -o|--output)
            TEST_OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RUNNER_RED}错误: 未知选项 $1${RUNNER_NC}" >&2
            show_help
            exit 1
            ;;
    esac
done

# 创建输出目录
mkdir -p "$TEST_OUTPUT_DIR"

# 设置测试环境
export TEST_OUTPUT_DIR

echo -e "${RUNNER_BLUE}=== CI/CD 测试套件 ===${RUNNER_NC}"
echo -e "工作目录: $PROJECT_ROOT"
echo -e "输出目录: $TEST_OUTPUT_DIR"
echo -e "详细模式: $TEST_VERBOSE"
echo -e "覆盖率: $TEST_COVERAGE"
echo

# 总体统计
TOTAL_PASSED=0
TOTAL_FAILED=0
FAILED_SUITES=()

# 运行测试套件
run_test_suite() {
    local suite_name="$1"
    local suite_path="$2"
    local output_file="$TEST_OUTPUT_DIR/${suite_name}.log"
    
    echo -e "${RUNNER_BLUE}运行 $suite_name...${RUNNER_NC}"
    
    # 运行测试并捕获输出
    cd "$PROJECT_ROOT" && bash "$suite_path" > "$output_file" 2>&1
    local test_exit_code=$?
    
    # 检查是否包含"所有测试通过"来判断成功
    if grep -q "所有测试通过" "$output_file"; then
        local passed=$(grep "通过:" "$output_file" | awk '{print $2}' || echo "0")
        local total=$(grep "总测试数:" "$output_file" | awk '{print $2}' || echo "0")
        echo -e "  ${RUNNER_GREEN}✓ $suite_name ($passed/$total 通过)${RUNNER_NC}"
        TOTAL_PASSED=$((TOTAL_PASSED + 1))
        return 0
    else
        echo -e "  ${RUNNER_RED}✗ $suite_name${RUNNER_NC}"
        TOTAL_FAILED=$((TOTAL_FAILED + 1))
        FAILED_SUITES+=("$suite_name")
        return 1
    fi
}

# 运行单元测试
if [ "$UNIT_TESTS" = true ]; then
    echo -e "${RUNNER_YELLOW}=== 单元测试 ===${RUNNER_NC}"

    # 核心库测试
    run_test_suite "核心库测试" "$SCRIPT_DIR/unit/test-core.sh"

    # 配置管理测试
    run_test_suite "配置管理测试" "$SCRIPT_DIR/unit/test-config-simple.sh"

    # aicd 主程序测试
    if [ -f "$SCRIPT_DIR/unit/test-aicd.sh" ]; then
        run_test_suite "aicd主程序测试" "$SCRIPT_DIR/unit/test-aicd.sh"
    fi

    # 颜色库测试
    if [ -f "$SCRIPT_DIR/unit/test-utils-colors.sh" ]; then
        run_test_suite "颜色库测试" "$SCRIPT_DIR/unit/test-utils-colors.sh"
    fi
fi

# 运行集成测试
if [ "$INTEGRATION_TESTS" = true ]; then
    echo -e "\n${RUNNER_YELLOW}=== 集成测试 ===${RUNNER_NC}"
    
    # 查找并运行所有集成测试
    for test_file in "$SCRIPT_DIR/integration/"*.sh; do
        if [ -f "$test_file" ]; then
            local suite_name=$(basename "$test_file" .sh)
            run_test_suite "$suite_name" "$test_file"
        fi
    done
fi

# 生成覆盖率报告（如果启用）
if [ "$TEST_COVERAGE" = true ]; then
    echo -e "\n${RUNNER_YELLOW}=== 生成覆盖率报告 ===${RUNNER_NC}"

    # 使用覆盖率脚本
    if [ -f "$SCRIPT_DIR/coverage.sh" ]; then
        bash "$SCRIPT_DIR/coverage.sh" --html
    else
        echo "覆盖率脚本不存在: $SCRIPT_DIR/coverage.sh"
    fi
fi

# 打印最终结果
echo -e "\n${RUNNER_BLUE}=== 测试总结 ===${RUNNER_NC}"
echo -e "通过的套件: ${RUNNER_GREEN}$TOTAL_PASSED${RUNNER_NC}"
echo -e "失败的套件: ${RUNNER_RED}$TOTAL_FAILED${RUNNER_NC}"

if [ $TOTAL_FAILED -gt 0 ]; then
    echo -e "\n${RUNNER_RED}失败的测试套件:${RUNNER_NC}"
    for suite in "${FAILED_SUITES[@]}"; do
        echo -e "  - $suite"
    done
    echo -e "\n查看详细日志: $TEST_OUTPUT_DIR/"
    echo -e "${RUNNER_RED}=== 测试失败 ===${RUNNER_NC}"
    exit 1
else
    echo -e "\n${RUNNER_GREEN}=== 所有测试通过 ===${RUNNER_NC}"
    exit 0
fi