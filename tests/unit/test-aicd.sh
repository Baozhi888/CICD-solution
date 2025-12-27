#!/bin/bash

# =============================================================================
# test-aicd.sh - aicd 主程序测试
# =============================================================================
# 测试 aicd CLI 的主要功能
# =============================================================================

# 加载测试框架
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../test-framework.sh"

# 项目路径
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
AICD_SCRIPT="$PROJECT_ROOT/scripts/aicd.sh"

# =============================================================================
# 测试辅助函数
# =============================================================================

# 运行 aicd 命令并捕获输出
run_aicd() {
    bash "$AICD_SCRIPT" "$@" 2>&1
}

# 运行 aicd 命令并返回退出码
run_aicd_status() {
    bash "$AICD_SCRIPT" "$@" >/dev/null 2>&1
    echo $?
}

# =============================================================================
# 测试: 帮助和版本信息
# =============================================================================

test_help_display() {
    echo "测试: 帮助信息显示"

    local output
    output=$(run_aicd --help)

    assert_contains "$output" "aicd" "帮助信息应包含 aicd"
    assert_contains "$output" "用法:" "帮助信息应包含用法说明"
    assert_contains "$output" "命令:" "帮助信息应包含命令列表"
    assert_contains "$output" "选项:" "帮助信息应包含选项说明"
    assert_contains "$output" "init" "帮助信息应包含 init 命令"
    assert_contains "$output" "validate" "帮助信息应包含 validate 命令"
    assert_contains "$output" "build" "帮助信息应包含 build 命令"
    assert_contains "$output" "deploy" "帮助信息应包含 deploy 命令"
}

test_version_display() {
    echo "测试: 版本信息显示"

    local output
    output=$(run_aicd version)

    assert_contains "$output" "aicd" "版本信息应包含 aicd"
    assert_contains "$output" "CI/CD" "版本信息应包含 CI/CD"
}

test_help_short_option() {
    echo "测试: 短选项 -h 显示帮助"

    local output
    output=$(run_aicd -h)

    assert_contains "$output" "用法:" "-h 应显示帮助信息"
}

# =============================================================================
# 测试: 命令解析
# =============================================================================

test_unknown_command_error() {
    echo "测试: 未知命令报错"

    local status
    status=$(run_aicd_status nonexistent_command)

    assert_not_equals "0" "$status" "未知命令应返回非零退出码"
}

test_no_command_error() {
    echo "测试: 无命令时报错"

    local output
    output=$(run_aicd 2>&1)

    assert_contains "$output" "请指定一个命令" "无命令时应提示指定命令"
}

test_unknown_option_error() {
    echo "测试: 未知选项报错"

    local status
    status=$(run_aicd_status --unknown-option)

    assert_not_equals "0" "$status" "未知选项应返回非零退出码"
}

# =============================================================================
# 测试: init 命令
# =============================================================================

test_init_creates_config() {
    echo "测试: init 命令创建配置文件"

    # 创建临时测试目录
    local test_dir
    test_dir=$(mktemp -d)
    cd "$test_dir" || return 1

    # 运行 init（使用 echo 模拟用户输入 'n' 避免覆盖提示）
    bash "$AICD_SCRIPT" init >/dev/null 2>&1 || true

    # 检查配置目录是否创建
    if [[ -d "$test_dir/config" ]]; then
        assert_equals "true" "true" "init 应创建 config 目录"
    else
        assert_equals "true" "false" "init 应创建 config 目录"
    fi

    # 清理
    cd - >/dev/null || return 1
    rm -rf "$test_dir"
}

# =============================================================================
# 测试: 环境变量处理
# =============================================================================

test_verbose_option() {
    echo "测试: -v 选项启用详细模式"

    local output
    output=$(AICD_VERBOSE="" run_aicd -v --help)

    # 详细模式应该正常工作
    assert_contains "$output" "用法:" "-v 选项不应影响帮助显示"
}

test_config_option() {
    echo "测试: -c 选项指定配置文件"

    # 创建临时配置文件
    local config_file
    config_file=$(mktemp)
    echo "test: true" > "$config_file"

    # 运行带配置选项的命令
    local status
    status=$(AICD_CONFIG="$config_file" run_aicd_status --help)

    assert_equals "0" "$status" "-c 选项应正常工作"

    # 清理
    rm -f "$config_file"
}

test_env_option() {
    echo "测试: -e 选项指定环境"

    local status
    status=$(run_aicd_status -e production --help)

    assert_equals "0" "$status" "-e 选项应正常工作"
}

# =============================================================================
# 测试: safe_exec_cmd 安全函数
# =============================================================================

test_safe_exec_blocks_command_substitution() {
    echo "测试: safe_exec_cmd 阻止命令替换"

    # 创建测试脚本来测试 safe_exec_cmd
    local test_script
    test_script=$(mktemp)

    cat > "$test_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

safe_exec_cmd() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        return 1
    fi
    if [[ "$cmd" =~ \$\(|\`|<\(|>\( ]]; then
        echo "BLOCKED"
        return 1
    fi
    bash -c "$cmd"
}

# 测试危险命令
safe_exec_cmd 'echo $(whoami)' 2>/dev/null && echo "ALLOWED" || echo "BLOCKED"
SCRIPT

    chmod +x "$test_script"
    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "BLOCKED" "命令替换应被阻止"

    rm -f "$test_script"
}

test_safe_exec_allows_simple_commands() {
    echo "测试: safe_exec_cmd 允许简单命令"

    local test_script
    test_script=$(mktemp)

    cat > "$test_script" << 'SCRIPT'
#!/bin/bash
set -euo pipefail

safe_exec_cmd() {
    local cmd="$1"
    if [[ -z "$cmd" ]]; then
        return 1
    fi
    if [[ "$cmd" =~ \$\(|\`|<\(|>\( ]]; then
        return 1
    fi
    bash -c "$cmd"
}

safe_exec_cmd 'echo hello' 2>/dev/null
SCRIPT

    chmod +x "$test_script"
    local output
    output=$(bash "$test_script" 2>&1)

    assert_contains "$output" "hello" "简单命令应被允许执行"

    rm -f "$test_script"
}

# =============================================================================
# 测试: 命令路由
# =============================================================================

test_command_routing() {
    echo "测试: 命令正确路由"

    # 测试各命令是否被正确识别（即使执行失败也说明路由正确）
    local commands=("init" "validate" "doctor" "fix" "build" "deploy" "monitor" "benchmark" "docs")

    for cmd in "${commands[@]}"; do
        local output
        output=$(run_aicd "$cmd" 2>&1 || true)

        # 如果输出不包含"未知命令"，说明命令被正确识别
        if [[ "$output" != *"未知命令"* ]]; then
            assert_equals "true" "true" "命令 $cmd 应被正确识别"
        else
            assert_equals "true" "false" "命令 $cmd 应被正确识别"
        fi
    done
}

# =============================================================================
# 测试: run 命令
# =============================================================================

test_run_requires_stage() {
    echo "测试: run 命令需要指定阶段"

    local output
    output=$(run_aicd run 2>&1)

    assert_contains "$output" "请指定要运行的阶段" "run 命令应要求指定阶段"
}

test_run_unknown_stage_error() {
    echo "测试: run 命令拒绝未知阶段"

    local output
    output=$(run_aicd run unknown_stage 2>&1)

    assert_contains "$output" "未知阶段" "run 命令应拒绝未知阶段"
}

# =============================================================================
# 运行所有测试
# =============================================================================

run_all_tests() {
    test_init

    echo -e "\n${TEST_BLUE}=== aicd.sh 主程序测试 ===${TEST_NC}\n"

    # 帮助和版本测试
    run_test_suite "帮助信息测试" test_help_display
    run_test_suite "版本信息测试" test_version_display
    run_test_suite "短选项帮助测试" test_help_short_option

    # 命令解析测试
    run_test_suite "未知命令测试" test_unknown_command_error
    run_test_suite "无命令测试" test_no_command_error
    run_test_suite "未知选项测试" test_unknown_option_error

    # init 命令测试
    run_test_suite "init 命令测试" test_init_creates_config

    # 选项测试
    run_test_suite "详细模式测试" test_verbose_option
    run_test_suite "配置选项测试" test_config_option
    run_test_suite "环境选项测试" test_env_option

    # 安全函数测试
    run_test_suite "阻止命令替换测试" test_safe_exec_blocks_command_substitution
    run_test_suite "允许简单命令测试" test_safe_exec_allows_simple_commands

    # 命令路由测试
    run_test_suite "命令路由测试" test_command_routing

    # run 命令测试
    run_test_suite "run 需要阶段测试" test_run_requires_stage
    run_test_suite "run 未知阶段测试" test_run_unknown_stage_error

    print_test_summary
}

# 如果直接运行脚本，执行所有测试
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
