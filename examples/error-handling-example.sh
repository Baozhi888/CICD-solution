#!/bin/bash

# 示例脚本：演示统一错误处理的使用
# 使用 lib/core-loader.sh 加载所有核心库

# 加载核心库
source "$(dirname "$0")/../lib/core-loader.sh"

# 设置脚本模块名称
set_log_module "ExampleScript"

# 脚本配置
CONFIG_FILE="${1:-config.yaml}"
OUTPUT_DIR="${2:-output}"

# 清理函数
cleanup_on_exit() {
    log_info "执行清理操作..."
    # 清理临时文件等
    rm -f /tmp/example-script-*
}

# 主函数
main() {
    log_info "开始执行示例脚本"
    
    # 验证必需的文件
    validate_required_files "$CONFIG_FILE"
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 使用重试机制执行命令
    execute_with_retry "curl -s https://api.github.com/users/octocat" 3 2
    
    # 使用超时执行命令
    execute_with_timeout "sleep 10" 5
    
    # 模拟一个可能失败的操作
    push_error_context "processing:data"
    
    if ! process_data; then
        log_error "数据处理失败"
        return $E_GENERAL
    fi
    
    pop_error_context
    
    log_info "脚本执行成功"
}

# 数据处理函数
process_data() {
    log_debug "处理数据..."
    
    # 模拟处理
    echo "处理数据" > "$OUTPUT_DIR/result.txt"
    
    return 0
}

# 使用错误处理包装器运行主函数
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    # 使用错误处理包装器
    with_error_handling "main" main
fi