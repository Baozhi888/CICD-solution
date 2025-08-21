#!/bin/bash

# 配置版本管理库单元测试
# 测试 lib/core/config-versioning.sh

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的库
# 为了避免实际的文件系统操作，我们将在测试中 mock 一些关键函数
source "$(dirname "$0")/../../lib/core/logging.sh"
source "$(dirname "$0")/../../lib/core/config-versioning.sh"

# --- Mock 函数 ---

# Mock mkdir 和 cp 命令以避免实际的文件系统更改
mkdir() { 
    echo "MOCK: mkdir $*" >&2
    command mkdir -p "$TEST_TMP_DIR/mocked_paths/$(echo "$*" | grep -o '[^ ]*$')" 2>/dev/null || true
}
export -f mkdir

cp() { 
    echo "MOCK: cp $*" >&2
    # 在 mock 环境中创建一个空文件来模拟复制
    local dest="${*: -1}" # 获取最后一个参数作为目标
    touch "$dest" 2>/dev/null || true
}
export -f cp

# --- 测试用例 ---

test_version_compare() {
    echo "测试版本号比较..."
    
    assert_equals "0" "$(version_compare "1.0.0" "1.0.0")" "相同版本号应返回 0"
    assert_equals "1" "$(version_compare "2.0.0" "1.0.0")" "大版本号应返回 1"
    assert_equals "-1" "$(version_compare "1.0.0" "2.0.0")" "小版本号应返回 -1"
    assert_equals "1" "$(version_compare "1.10.0" "1.2.0")" "修订版比较应正确"
    assert_equals "-1" "$(version_compare "1.0.1" "1.0.10")" "修订版比较应正确"
}

test_get_and_set_config_version() {
    echo "测试获取和设置配置版本..."
    
    # 设置测试环境
    CONFIG_VERSION_DIR="$TEST_TMP_DIR/config_versions"
    CONFIG_CURRENT_VERSION_FILE="$CONFIG_VERSION_DIR/current-version"
    mkdir -p "$CONFIG_VERSION_DIR"
    
    # 1. 测试获取默认版本
    local default_version=$(get_config_version)
    assert_equals "1.0.0" "$default_version" "默认版本应为 1.0.0"
    
    # 2. 测试设置和获取版本
    local test_version="2.1.3"
    set_config_version "$test_version"
    local retrieved_version=$(get_config_version)
    assert_equals "$test_version" "$retrieved_version" "设置和获取的版本应一致"
}

test_backup_config() {
    echo "测试配置备份..."
    
    # 设置测试环境
    CONFIG_VERSION_DIR="$TEST_TMP_DIR/config_versions"
    mkdir -p "$CONFIG_VERSION_DIR"
    
    local config_file=$(create_test_file "test_config.yaml" "key: value")
    local version="1.2.3"
    
    # 执行备份
    local backup_result=$(backup_config "$config_file" "$version")
    
    # 验证结果
    assert_not_empty "$backup_result" "备份应返回备份文件路径"
    assert_contains "$backup_result" "$CONFIG_VERSION_DIR/backup/$version" "备份路径应包含版本目录"
    
    # 验证元数据文件是否存在
    local meta_file="${backup_result}.meta"
    assert_file_exists "$meta_file" "应创建元数据文件"
    assert_contains "$(cat "$meta_file")" "version=$version" "元数据应包含版本信息"
}

test_create_config_version() {
    echo "测试创建配置版本..."
    
    # 设置测试环境
    CONFIG_VERSION_DIR="$TEST_TMP_DIR/config_versions"
    mkdir -p "$CONFIG_VERSION_DIR"
    
    local config_file=$(create_test_file "test_config_for_version.yaml" "key: value")
    local version="3.0.0"
    local message="测试版本创建"
    
    # 创建配置版本
    create_config_version "$config_file" "$version" "$message"
    
    # 验证版本信息文件
    local version_info_file="$CONFIG_VERSION_DIR/versions/$version/version.json"
    assert_file_exists "$version_info_file" "应创建版本信息文件"
    assert_contains "$(cat "$version_info_file")" "\"version\": \"$version\"" "版本信息应包含版本号"
    assert_contains "$(cat "$version_info_file")" "\"message\": \"$message\"" "版本信息应包含说明"
}

test_list_config_versions() {
    echo "测试列出配置版本..."
    
    # 设置测试环境
    CONFIG_VERSION_DIR="$TEST_TMP_DIR/config_versions"
    mkdir -p "$CONFIG_VERSION_DIR"
    
    # 创建几个测试版本
    local config_file=$(create_test_file "dummy.yaml" "key: value")
    create_config_version "$config_file" "1.0.0" "初始版本"
    create_config_version "$config_file" "2.0.0" "重大更新"
    
    # 捕获 list_config_versions 的输出
    local list_output
    list_output=$(list_config_versions)
    
    # 验证输出
    assert_contains "$list_output" "配置版本历史:" "输出应包含标题"
    assert_contains "$list_output" "版本: 1.0.0" "输出应包含版本 1.0.0"
    assert_contains "$list_output" "版本: 2.0.0" "输出应包含版本 2.0.0"
    assert_contains "$list_output" "说明: 初始版本" "输出应包含版本说明"
    assert_contains "$list_output" "说明: 重大更新" "输出应包含版本说明"
}


# --- 主测试函数 ---

run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "版本比较" test_version_compare
    run_test_suite "版本获取与设置" test_get_and_set_config_version
    run_test_suite "配置备份" test_backup_config
    run_test_suite "创建版本" test_create_config_version
    run_test_suite "列出版本" test_list_config_versions
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi