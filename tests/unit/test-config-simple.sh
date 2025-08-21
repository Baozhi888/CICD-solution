#!/bin/bash

# 配置管理器简化测试
# 测试基本的配置管理功能

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 设置测试环境
CONFIG_DIR="$TEST_TMP_DIR/config"
mkdir -p "$CONFIG_DIR"

# 创建测试配置文件
create_test_config() {
    cat > "$CONFIG_DIR/test.yaml" << EOF
global:
  app_name: "TestApp"
  version: "1.0.0"
  
build:
  output_dir: "dist"
  cache: true
  
deploy:
  environments:
    - development
    - staging
    production
  auto_rollback: true
EOF
}

test_config_loading() {
    echo "测试配置加载..."
    
    create_test_config
    
    # 设置环境变量测试
    export CFG_GLOBAL_APP_NAME="EnvApp"
    
    # 加载配置管理器
    source "$(dirname "$0")/../../lib/core/config-manager.sh"
    
    # 测试环境变量优先级
    local app_name=$(get_config "global.app_name" "default")
    assert_equals "EnvApp" "$app_name" "应该使用环境变量值"
    
    # 清除环境变量
    unset CFG_GLOBAL_APP_NAME
    
    # 测试默认值
    local missing_value=$(get_config "missing.key" "default")
    assert_equals "default" "$missing_value" "应该返回默认值"
}

test_config_validation() {
    echo "测试配置验证..."
    
    create_test_config
    
    source "$(dirname "$0")/../../lib/core/config-manager.sh"
    source "$(dirname "$0")/../../lib/core/validation.sh"
    
    # 测试文件存在性
    assert_file_exists "$CONFIG_DIR/test.yaml" "配置文件应该存在"
    
    # 测试基本的 YAML 语法（如果有 yq）
    if command -v yq >/dev/null 2>&1; then
        assert_command_succeeds "yq eval '.' '$CONFIG_DIR/test.yaml' >/dev/null" "YAML 应该是有效的"
    fi
}

# 主测试函数
run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "配置加载" test_config_loading
    run_test_suite "配置验证" test_config_validation
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi