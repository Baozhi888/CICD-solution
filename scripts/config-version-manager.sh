#!/bin/bash

# 配置版本管理工具
# 管理配置文件的版本控制、迁移和回滚

# 加载核心库
source "$(dirname "$0")/../lib/core-loader.sh"

# 设置模块名称
set_log_module "ConfigVersionManager"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 <命令> [选项]

CI/CD 配置版本管理工具

命令:
  init                      初始化配置版本管理
  version                   显示当前配置版本
  create <version> [msg]     创建新版本
  list                      列出所有版本
  rollback <version>         回滚到指定版本
  migrate <version>          迁移到指定版本
  backup [file]              备份配置文件
  validate <version>         验证配置版本
  create-migration <from> <to> [name]  创建迁移脚本

选项:
  -f, --file FILE           配置文件路径
  -d, --dir DIR             版本存储目录
  -h, --help                显示此帮助信息

环境变量:
  CONFIG_FILE               配置文件路径
  CONFIG_VERSION_DIR        版本存储目录

示例:
  $0 init                   # 初始化版本管理
  $0 create 2.0.0 "添加新功能"  # 创建版本 2.0.0
  $0 list                  # 列出所有版本
  $0 rollback 1.0.0        # 回滚到版本 1.0.0
  $0 migrate 2.0.0         # 迁移到版本 2.0.0
EOF
}

# 初始化配置版本管理
cmd_init() {
    log_info "初始化配置版本管理..."
    
    init_config_versioning
    
    # 创建配置目录结构
    mkdir -p config/migrations
    mkdir -p config/versions
    
    log_info "配置版本管理已初始化"
    echo "版本存储目录: $CONFIG_VERSION_DIR"
    echo "迁移脚本目录: $CONFIG_MIGRATIONS_DIR"
}

# 显示当前版本
cmd_version() {
    local config_file="${CONFIG_FILE:-config/central-config.yaml}"
    
    if [ ! -f "$config_file" ]; then
        log_warn "配置文件不存在: $config_file"
        echo "未初始化"
        return 1
    fi
    
    local version=$(get_config_version)
    echo "当前配置版本: $version"
    
    # 显示版本信息
    if [ -f "$CONFIG_VERSION_DIR/versions/$version/version.json" ]; then
        echo ""
        echo "版本信息:"
        get_config_version_info "$version" | jq '.' 2>/dev/null || \
        get_config_version_info "$version"
    fi
}

# 创建新版本
cmd_create() {
    local version="$1"
    local message="${2:-"配置更新"}"
    local config_file="${CONFIG_FILE:-config/central-config.yaml}"
    
    if [ -z "$version" ]; then
        log_error "请指定版本号"
        return 1
    fi
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    create_config_version "$config_file" "$version" "$message"
}

# 列出所有版本
cmd_list() {
    list_config_versions
}

# 回滚版本
cmd_rollback() {
    local version="$1"
    local config_file="${CONFIG_FILE:-config/central-config.yaml}"
    
    if [ -z "$version" ]; then
        log_error "请指定目标版本"
        return 1
    fi
    
    rollback_config_version "$config_file" "$version"
}

# 迁移版本
cmd_migrate() {
    local version="$1"
    local config_file="${CONFIG_FILE:-config/central-config.yaml}"
    
    if [ -z "$version" ]; then
        log_error "请指定目标版本"
        return 1
    fi
    
    run_migration "$config_file" "$version"
}

# 备份配置
cmd_backup() {
    local config_file="${1:-${CONFIG_FILE:-config/central-config.yaml}}"
    local version=$(get_config_version)
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    local backup_file=$(backup_config "$config_file" "manual-$(date +"%Y%m%d%H%M%S")")
    log_info "配置已备份: $backup_file"
}

# 验证版本
cmd_validate() {
    local version="$1"
    local config_file="${CONFIG_FILE:-config/central-config.yaml}"
    
    if [ -z "$version" ]; then
        log_error "请指定要验证的版本"
        return 1
    fi
    
    if validate_config_version "$config_file" "$version"; then
        log_info "配置版本验证通过"
    else
        log_error "配置版本验证失败"
        return 1
    fi
}

# 创建迁移脚本
cmd_create_migration() {
    local from_version="$1"
    local to_version="$2"
    local migration_name="${3:-}"
    
    if [ -z "$from_version" ] || [ -z "$to_version" ]; then
        log_error "请指定源版本和目标版本"
        return 1
    fi
    
    create_migration "$from_version" "$to_version" "$migration_name"
}

# 显示配置差异
cmd_diff() {
    local version1="$1"
    local version2="$2"
    
    if [ -z "$version1" ] || [ -z "$version2" ]; then
        log_error "请指定两个版本号"
        return 1
    fi
    
    # 获取两个版本的备份文件
    local backup1=$(get_config_version_info "$version1" | grep -o '"backup_file": "[^"]*"' | cut -d'"' -f4)
    local backup2=$(get_config_version_info "$version2" | grep -o '"backup_file": "[^"]*"' | cut -d'"' -f4)
    
    if [ ! -f "$backup1" ]; then
        log_error "版本 $version1 的备份文件不存在"
        return 1
    fi
    
    if [ ! -f "$backup2" ]; then
        log_error "版本 $version2 的备份文件不存在"
        return 1
    fi
    
    # 显示差异
    echo "配置差异: $version1 -> $version2"
    echo "----------------------------------------"
    
    if command -v diff >/dev/null 2>&1; then
        diff -u "$backup1" "$backup2" || true
    elif command -v git >/dev/null 2>&1; then
        git diff --no-index "$backup1" "$backup2" || true
    else
        log_error "未找到 diff 或 git 命令"
        return 1
    fi
}

# 导出配置
cmd_export() {
    local version="$1"
    local output_dir="${2:-.}"
    
    if [ -z "$version" ]; then
        log_error "请指定要导出的版本"
        return 1
    fi
    
    local version_info=$(get_config_version_info "$version")
    local backup_file=$(echo "$version_info" | grep -o '"backup_file": "[^"]*"' | cut -d'"' -f4)
    
    if [ ! -f "$backup_file" ]; then
        log_error "版本 $version 的备份文件不存在"
        return 1
    fi
    
    local output_file="$output_dir/config-v$version.yaml"
    cp "$backup_file" "$output_file"
    
    log_info "配置已导出: $output_file"
}

# 解析命令行参数
COMMAND=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--file)
            export CONFIG_FILE="$2"
            shift 2
            ;;
        -d|--dir)
            export CONFIG_VERSION_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        init|version|create|list|rollback|migrate|backup|validate|create-migration|diff|export)
            COMMAND="$1"
            shift
            ;;
        *)
            # 剩余参数作为命令参数
            break
            ;;
    esac
done

# 执行命令
case "$COMMAND" in
    "init")
        cmd_init
        ;;
    "version")
        cmd_version
        ;;
    "create")
        cmd_create "$@"
        ;;
    "list")
        cmd_list
        ;;
    "rollback")
        cmd_rollback "$@"
        ;;
    "migrate")
        cmd_migrate "$@"
        ;;
    "backup")
        cmd_backup "$@"
        ;;
    "validate")
        cmd_validate "$@"
        ;;
    "create-migration")
        cmd_create_migration "$@"
        ;;
    "diff")
        cmd_diff "$@"
        ;;
    "export")
        cmd_export "$@"
        ;;
    *)
        log_error "未知命令: $COMMAND"
        show_help
        exit 1
        ;;
esac