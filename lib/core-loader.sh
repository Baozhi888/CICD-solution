#!/bin/bash

# CI/CD 核心库加载器
# 统一加载所有核心库函数

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$(dirname "$SCRIPT_DIR")/lib/core"

# 加载核心库
source "$LIB_DIR/enhanced-logging.sh"
source "$LIB_DIR/utils.sh"
source "$LIB_DIR/validation.sh"
source "$LIB_DIR/config-manager.sh"
source "$LIB_DIR/error-handler.sh"
source "$LIB_DIR/config-versioning.sh"

# 初始化配置管理器（如果需要）
if command -v init_config_manager >/dev/null 2>&1; then
    init_config_manager >/dev/null 2>&1 || true
fi

# 初始化错误处理器
init_error_handler

# 初始化配置版本管理
if command -v init_config_versioning >/dev/null 2>&1; then
    init_config_versioning >/dev/null 2>&1 || true
fi

# 设置默认日志模块
set_log_module "CI/CD-Core"