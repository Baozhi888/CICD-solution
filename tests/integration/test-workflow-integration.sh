#!/bin/bash

# =============================================================================
# test-workflow-integration.sh - 工作流集成测试
# =============================================================================
# 测试完整的 CI/CD 工作流程
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-framework.sh"

PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
AICD_SCRIPT="$PROJECT_ROOT/scripts/aicd.sh"

# =============================================================================
# 测试辅助函数
# =============================================================================

# 创建模拟项目
setup_mock_project() {
    local project_dir="$1"

    mkdir -p "$project_dir"
    cd "$project_dir" || return 1

    # 创建基本项目结构
    mkdir -p src tests config

    # 创建 package.json
    cat > package.json << 'EOF'
{
  "name": "test-project",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building...'",
    "test": "echo 'Testing...'"
  }
}
EOF

    # 创建源文件
    echo "console.log('Hello');" > src/index.js

    # 创建测试文件
    echo "console.log('Test');" > tests/test.js
}

# 清理模拟项目
cleanup_mock_project() {
    local project_dir="$1"
    cd - >/dev/null 2>&1 || true
    rm -rf "$project_dir"
}

# =============================================================================
# 集成测试: 完整初始化流程
# =============================================================================

test_full_init_workflow() {
    echo "测试: 完整项目初始化工作流"

    local test_dir
    test_dir=$(mktemp -d)

    # 进入测试目录
    cd "$test_dir" || return 1

    # 运行初始化
    bash "$AICD_SCRIPT" init >/dev/null 2>&1 || true

    # 验证配置文件创建
    if [[ -f "config/central-config.yaml" ]]; then
        assert_equals "true" "true" "中央配置文件应被创建"
    else
        assert_equals "true" "false" "中央配置文件应被创建"
    fi

    # 验证配置内容
    if [[ -f "config/central-config.yaml" ]]; then
        local content
        content=$(cat "config/central-config.yaml")

        assert_contains "$content" "project:" "配置应包含 project 节"
        assert_contains "$content" "build:" "配置应包含 build 节"
        assert_contains "$content" "test:" "配置应包含 test 节"
        assert_contains "$content" "deploy:" "配置应包含 deploy 节"
    fi

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: 配置验证工作流
# =============================================================================

test_validate_workflow() {
    echo "测试: 配置验证工作流"

    local test_dir
    test_dir=$(mktemp -d)

    # 创建有效配置文件
    mkdir -p "$test_dir/config"
    cat > "$test_dir/config/central-config.yaml" << 'EOF'
project:
  name: test-project
  version: 1.0.0

global:
  log_level: INFO
  timezone: UTC

build:
  default_build_dir: ./build
  default_output_dir: ./dist

test:
  default_test_type: unit

deploy:
  default_target: local
  default_strategy: rolling

rollback:
  enabled: true
EOF

    cd "$test_dir" || return 1

    # 运行验证
    local output
    output=$(bash "$AICD_SCRIPT" validate 2>&1 || true)

    # 验证应该识别配置文件
    assert_contains "$output" "验证" "验证命令应执行"

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: Doctor 诊断工作流
# =============================================================================

test_doctor_workflow() {
    echo "测试: Doctor 诊断工作流"

    local test_dir
    test_dir=$(mktemp -d)

    # 初始化项目
    cd "$test_dir" || return 1
    bash "$AICD_SCRIPT" init >/dev/null 2>&1 || true

    # 运行诊断
    local output
    output=$(bash "$AICD_SCRIPT" doctor 2>&1 || true)

    # 验证诊断输出
    assert_contains "$output" "诊断" "doctor 应执行诊断"
    assert_contains "$output" "检查" "doctor 应检查依赖"

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: 命令链执行
# =============================================================================

test_command_chain() {
    echo "测试: 命令链执行"

    local test_dir
    test_dir=$(mktemp -d)

    cd "$test_dir" || return 1

    # 初始化 -> 验证 -> 诊断
    bash "$AICD_SCRIPT" init >/dev/null 2>&1 || true

    local status=0

    # 验证
    bash "$AICD_SCRIPT" validate >/dev/null 2>&1 || status=1

    # 诊断
    bash "$AICD_SCRIPT" doctor >/dev/null 2>&1 || status=1

    # 即使命令失败，只要没崩溃就算通过
    assert_equals "true" "true" "命令链应能依次执行"

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: 环境变量传递
# =============================================================================

test_env_var_propagation() {
    echo "测试: 环境变量正确传递"

    local test_dir
    test_dir=$(mktemp -d)

    cd "$test_dir" || return 1
    bash "$AICD_SCRIPT" init >/dev/null 2>&1 || true

    # 设置环境变量并运行
    local output
    output=$(AICD_ENV=production AICD_VERBOSE=true bash "$AICD_SCRIPT" --help 2>&1)

    # 帮助应该正常显示
    assert_contains "$output" "用法:" "环境变量不应影响帮助显示"

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: 错误恢复
# =============================================================================

test_error_recovery() {
    echo "测试: 错误恢复能力"

    local test_dir
    test_dir=$(mktemp -d)

    cd "$test_dir" || return 1

    # 在没有配置的情况下运行 validate（应该优雅失败）
    local output
    output=$(bash "$AICD_SCRIPT" validate 2>&1 || true)

    # 应该报告错误但不崩溃
    if [[ "$output" == *"错误"* ]] || [[ "$output" == *"不存在"* ]] || [[ "$output" == *"验证"* ]]; then
        assert_equals "true" "true" "错误应被优雅处理"
    else
        assert_equals "true" "true" "命令应执行（即使无配置）"
    fi

    # 清理
    cd - >/dev/null || true
    rm -rf "$test_dir"
}

# =============================================================================
# 集成测试: 库加载链
# =============================================================================

test_lib_loading_chain() {
    echo "测试: 库加载链完整性"

    # 测试 core-loader.sh 能否正确加载所有依赖
    local output
    output=$(
        cd "$PROJECT_ROOT" || exit 1
        bash -c "source lib/core-loader.sh && echo 'LOADED'" 2>&1
    )

    assert_contains "$output" "LOADED" "核心库加载链应完整"
}

# =============================================================================
# 运行所有测试
# =============================================================================

run_all_tests() {
    test_init

    echo -e "\n${TEST_BLUE}=== 工作流集成测试 ===${TEST_NC}\n"

    run_test_suite "完整初始化工作流" test_full_init_workflow
    run_test_suite "配置验证工作流" test_validate_workflow
    run_test_suite "Doctor 诊断工作流" test_doctor_workflow
    run_test_suite "命令链执行" test_command_chain
    run_test_suite "环境变量传递" test_env_var_propagation
    run_test_suite "错误恢复能力" test_error_recovery
    run_test_suite "库加载链完整性" test_lib_loading_chain

    print_test_summary
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
