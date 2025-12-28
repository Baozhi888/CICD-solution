#!/bin/bash

# CI/CD 核心库加载器
# 统一加载所有核心库函数

# 获取脚本所在目录
CORE_LOADER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_CORE_DIR="${CORE_LOADER_DIR}/core"
LIB_UTILS_DIR="${CORE_LOADER_DIR}/utils"

# =============================================================================
# 加载工具库（优先加载，提供基础功能）
# =============================================================================
if [[ -f "$LIB_UTILS_DIR/colors.sh" ]]; then
    source "$LIB_UTILS_DIR/colors.sh"
fi

if [[ -f "$LIB_UTILS_DIR/args-parser.sh" ]]; then
    source "$LIB_UTILS_DIR/args-parser.sh"
fi

# =============================================================================
# 加载核心库
# =============================================================================
source "$LIB_CORE_DIR/enhanced-logging.sh"
source "$LIB_CORE_DIR/utils.sh"
source "$LIB_CORE_DIR/validation.sh"
source "$LIB_CORE_DIR/config-manager.sh"
source "$LIB_CORE_DIR/error-handler.sh"
source "$LIB_CORE_DIR/config-versioning.sh"

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
if command -v set_log_module >/dev/null 2>&1; then
    set_log_module "CI/CD-Core"
fi

# =============================================================================
# 可选：加载 AI 模块
# =============================================================================
LIB_AI_DIR="${CORE_LOADER_DIR}/ai"

# AI 模块加载函数
load_ai_modules() {
    if [[ -d "$LIB_AI_DIR" ]]; then
        # 按依赖顺序加载
        local ai_modules=(
            "ai-core.sh"
            "api-client.sh"
            "prompt-templates.sh"
            "log-analyzer.sh"
            "config-advisor.sh"
            "health-analyzer.sh"
            "alert-manager.sh"
        )

        for module in "${ai_modules[@]}"; do
            if [[ -f "$LIB_AI_DIR/$module" ]]; then
                source "$LIB_AI_DIR/$module"
            fi
        done

        # 初始化 AI 模块（如果已加载）
        if command -v ai_init >/dev/null 2>&1; then
            ai_init >/dev/null 2>&1 || true
        fi
    fi
}

# 如果设置了 AICD_LOAD_AI 环境变量，自动加载 AI 模块
if [[ "${AICD_LOAD_AI:-}" == "true" ]]; then
    load_ai_modules
fi