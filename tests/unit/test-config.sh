#!/bin/bash

# 配置管理器单元测试

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 设置测试环境
export CONFIG_DIR="$TEST_TMP_DIR/config"
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
    
    # 模拟配置加载
    source "$(dirname "$0")/../../lib/core/config-manager.sh"
    CONFIG_FILE="$CONFIG_DIR/test.yaml"
    
    # 测试配置读取
    local app_name=$(get_config "global.app_name")
    assert_equals "TestApp" "$app_name" "应该读取到正确的应用名称"
    
    local version=$(get_config "global.version")
    assert_equals "1.0.0" "$version" "应该读取到正确的版本"
    
    # 测试默认值
    local missing_value=$(get_config "missing.key" "default")
    assert_equals "default" "$missing_value" "应该返回默认值"
}

test_config_validation() {
    echo "测试配置验证..."
    
    create_test_config
    
    source "$(dirname "$0")/../../lib/core/config-manager.sh"
    source "$(dirname "$0")/../../lib/core/validation.sh"
    
    # 测试必需配置
    assert_command_succeeds "validate_config '$CONFIG_DIR/test.yaml'" "有效配置应该通过验证"
    
    # 测试无效配置
    echo "invalid: yaml: content" > "$CONFIG_DIR/invalid.yaml"
    assert_command_fails "validate_config '$CONFIG_DIR/invalid.yaml'" "无效配置应该被拒绝"
}

test_environment_override() {
    echo "测试环境覆盖..."
    
    create_test_config
    
    # 创建环境特定配置
    cat > "$CONFIG_DIR/test-prod.yaml" << EOF
global:
  app_name: "ProdApp"
  
deploy:
  auto_rollback: false
EOF
    
    source "$(dirname "$0")/../../lib/core/config-manager.sh"
    
    # 测试环境覆盖
    CONFIG_FILE="$CONFIG_DIR/test.yaml"
    ENV_CONFIG_FILE="$CONFIG_DIR/test-prod.yaml"
    
    # 模拟环境配置加载
    local app_name=$(get_config "global.app_name")
    assert_equals "ProdApp" "$app_name" "生产环境配置应该覆盖基础配置"
    
    local rollback=$(get_config "deploy.auto_rollback")
    assert_equals "false" "$rollback" "生产环境应该禁用自动回滚"
}

# 主测试函数
run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "配置加载" test_config_loading
    run_test_suite "配置验证" test_config_validation
    run_test_suite "环境覆盖" test_environment_override
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi