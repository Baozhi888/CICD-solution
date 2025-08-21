#!/bin/bash

# 配置版本管理机制
# 提供配置版本控制、迁移和回滚功能

# 配置版本管理配置
CONFIG_VERSION_ENABLED=${CONFIG_VERSION_ENABLED:-true}
CONFIG_VERSION_DIR="${CONFIG_VERSION_DIR:-/var/lib/cicd/config-versions}"
CONFIG_BACKUP_COUNT=${CONFIG_BACKUP_COUNT:-10}
CONFIG_AUTO_BACKUP=${CONFIG_AUTO_BACKUP:-true}
CONFIG_MIGRATION_ENABLED=${CONFIG_MIGRATION_ENABLED:-true}

# 版本格式定义
CONFIG_VERSION_FORMAT="${CONFIG_VERSION_FORMAT:-%Y%m%d-%H%M%S}"
CONFIG_CURRENT_VERSION_FILE="${CONFIG_VERSION_DIR}/current-version"
CONFIG_VERSION_SCHEMA="${CONFIG_VERSION_SCHEMA:-2}"

# 配置迁移脚本目录
CONFIG_MIGRATIONS_DIR="${CONFIG_MIGRATIONS_DIR:-$(dirname "$0")/../config/migrations}"

# 初始化配置版本管理
init_config_versioning() {
    # 确保版本目录存在
    mkdir -p "$CONFIG_VERSION_DIR" 2>/dev/null || true
    mkdir -p "$CONFIG_MIGRATIONS_DIR" 2>/dev/null || true
    
    # 初始化当前版本文件
    if [ ! -f "$CONFIG_CURRENT_VERSION_FILE" ]; then
        echo "1.0.0" > "$CONFIG_CURRENT_VERSION_FILE"
    fi
    
    # 创建示例迁移脚本
    create_example_migrations
}

# 获取当前配置版本
get_config_version() {
    if [ -f "$CONFIG_CURRENT_VERSION_FILE" ]; then
        cat "$CONFIG_CURRENT_VERSION_FILE"
    else
        echo "1.0.0"
    fi
}

# 设置配置版本
set_config_version() {
    local version="$1"
    
    echo "$version" > "$CONFIG_CURRENT_VERSION_FILE"
    log_info "配置版本设置为: $version"
}

# 备份配置文件
backup_config() {
    local config_file="$1"
    local version="$2"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    local backup_dir="$CONFIG_VERSION_DIR/backup/$version"
    mkdir -p "$backup_dir"
    
    local timestamp=$(date +"$CONFIG_VERSION_FORMAT")
    local backup_file="$backup_dir/$(basename "$config_file").$timestamp"
    
    # 复制配置文件
    cp "$config_file" "$backup_file"
    
    # 创建元数据文件
    cat > "$backup_file.meta" << EOF
timestamp=$(date -Iseconds)
version=$version
source=$(realpath "$config_file")
schema=$CONFIG_VERSION_SCHEMA
EOF
    
    log_info "配置已备份: $backup_file"
    
    # 清理旧备份
    cleanup_old_backups "$backup_dir"
    
    echo "$backup_file"
}

# 清理旧备份
cleanup_old_backups() {
    local backup_dir="$1"
    
    if [ ! -d "$backup_dir" ]; then
        return 0
    fi
    
    # 保留最新的 N 个备份
    ls -t "$backup_dir"/*.meta 2>/dev/null | tail -n +$((CONFIG_BACKUP_COUNT + 1)) | while read -r meta_file; do
        local backup_file="${meta_file%.meta}"
        rm -f "$backup_file" "$meta_file"
        log_debug "清理旧备份: $backup_file"
    done
}

# 创建配置版本
create_config_version() {
    local config_file="$1"
    local version="$2"
    local message="${3:-"配置更新"}"
    
    if [ -z "$config_file" ] || [ -z "$version" ]; then
        log_error "请指定配置文件和版本号"
        return 1
    fi
    
    log_info "创建配置版本: $version"
    
    # 备份当前配置
    local backup_file=$(backup_config "$config_file" "$version")
    
    # 更新当前版本
    set_config_version "$version"
    
    # 创建版本标签
    local version_dir="$CONFIG_VERSION_DIR/versions/$version"
    mkdir -p "$version_dir"
    
    # 创建版本信息
    cat > "$version_dir/version.json" << EOF
{
    "version": "$version",
    "timestamp": "$(date -Iseconds)",
    "message": "$message",
    "config_file": "$(realpath "$config_file")",
    "backup_file": "$backup_file",
    "schema": $CONFIG_VERSION_SCHEMA
}
EOF
    
    log_info "配置版本创建成功: $version"
}

# 获取配置版本信息
get_config_version_info() {
    local version="$1"
    local version_file="$CONFIG_VERSION_DIR/versions/$version/version.json"
    
    if [ ! -f "$version_file" ]; then
        log_error "版本不存在: $version"
        return 1
    fi
    
    cat "$version_file"
}

# 列出所有配置版本
list_config_versions() {
    local versions_dir="$CONFIG_VERSION_DIR/versions"
    
    if [ ! -d "$versions_dir" ]; then
        log_info "没有找到配置版本"
        return 0
    fi
    
    echo "配置版本历史:"
    echo "----------------------------------------"
    
    for version_dir in "$versions_dir"/*; do
        if [ -d "$version_dir" ] && [ -f "$version_dir/version.json" ]; then
            local version=$(basename "$version_dir")
            local info=$(get_config_version_info "$version")
            local timestamp=$(echo "$info" | grep -o '"timestamp": "[^"]*"' | cut -d'"' -f4)
            local message=$(echo "$info" | grep -o '"message": "[^"]*"' | cut -d'"' -f4)
            
            echo "版本: $version"
            echo "时间: $timestamp"
            echo "说明: $message"
            echo "----------------------------------------"
        fi
    done
}

# 回滚到指定版本
rollback_config_version() {
    local config_file="$1"
    local target_version="$2"
    
    if [ -z "$config_file" ] || [ -z "$target_version" ]; then
        log_error "请指定配置文件和目标版本"
        return 1
    fi
    
    log_info "回滚配置到版本: $target_version"
    
    # 获取版本信息
    local version_info=$(get_config_version_info "$target_version")
    local backup_file=$(echo "$version_info" | grep -o '"backup_file": "[^"]*"' | cut -d'"' -f4)
    
    if [ ! -f "$backup_file" ]; then
        log_error "找不到版本 $target_version 的备份文件"
        return 1
    fi
    
    # 备份当前配置
    local current_version=$(get_config_version)
    backup_config "$config_file" "rollback-$current_version-$(date +"%Y%m%d%H%M%S")"
    
    # 恢复配置
    cp "$backup_file" "$config_file"
    
    # 更新版本
    set_config_version "$target_version"
    
    log_info "配置回滚成功: $target_version"
}

# 创建迁移脚本
create_migration() {
    local from_version="$1"
    local to_version="$2"
    local migration_name="${3:-migration_${from_version}_to_${to_version}}"
    
    if [ -z "$from_version" ] || [ -z "$to_version" ]; then
        log_error "请指定源版本和目标版本"
        return 1
    fi
    
    local migration_file="$CONFIG_MIGRATIONS_DIR/${migration_name}.sh"
    
    # 创建迁移脚本模板
    cat > "$migration_file" << EOF
#!/bin/bash

# 配置迁移脚本: $from_version -> $to_version
# 创建时间: $(date -Iseconds)

# 加载核心库
source "\$(dirname "\$0")/../../lib/core-loader.sh"

set_log_module "ConfigMigration"

# 迁移函数
migrate_config() {
    local config_file="\$1"
    
    log_info "开始迁移配置: \$config_file"
    
    # 在这里添加迁移逻辑
    # 例如：
    # - 添加新的配置项
    # - 重命名配置项
    # - 删除废弃的配置项
    # - 转换配置值格式
    
    # 示例：使用 yq 或其他工具修改 YAML
    # if command -v yq >/dev/null 2>&1; then
    #     yq eval '.new_setting = "default_value"' -i "\$config_file"
    # fi
    
    log_info "配置迁移完成"
}

# 验证函数
validate_migration() {
    local config_file="\$1"
    
    # 验证迁移结果
    # 例如：
    # - 检查必需的配置项是否存在
    # - 验证配置值的有效性
    
    return 0
}

# 主函数
main() {
    local config_file="\${1:-config.yaml}"
    
    if [ ! -f "\$config_file" ]; then
        log_error "配置文件不存在: \$config_file"
        exit 1
    fi
    
    # 执行迁移
    migrate_config "\$config_file"
    
    # 验证迁移
    if validate_migration "\$config_file"; then
        log_info "迁移验证成功"
        exit 0
    else
        log_error "迁移验证失败"
        exit 1
    fi
}

# 如果直接运行此脚本
if [ "\${BASH_SOURCE[0]}" = "\${0}" ]; then
    main "\$@"
fi
EOF
    
    chmod +x "$migration_file"
    
    log_info "迁移脚本已创建: $migration_file"
    echo "请编辑迁移脚本以实现具体的迁移逻辑"
}

# 运行迁移
run_migration() {
    local config_file="$1"
    local target_version="$2"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    local current_version=$(get_config_version)
    
    if [ "$current_version" = "$target_version" ]; then
        log_info "配置版本已是目标版本: $target_version"
        return 0
    fi
    
    log_info "迁移配置: $current_version -> $target_version"
    
    # 查找合适的迁移脚本
    local migration_script="$CONFIG_MIGRATIONS_DIR/migration_${current_version//./_}_to_${target_version//./_}.sh"
    
    if [ ! -f "$migration_script" ]; then
        log_error "找不到迁移脚本: $migration_script"
        return 1
    fi
    
    # 备份当前配置
    backup_config "$config_file" "pre-migration-$current_version"
    
    # 运行迁移脚本
    if bash "$migration_script" "$config_file"; then
        # 更新版本
        set_config_version "$target_version"
        log_info "配置迁移成功: $target_version"
    else
        log_error "配置迁移失败"
        return 1
    fi
}

# 验证配置版本
validate_config_version() {
    local config_file="$1"
    local required_version="$2"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    local current_version=$(get_config_version)
    
    # 比较版本号
    if [ "$(version_compare "$current_version" "$required_version")" -lt 0 ]; then
        log_error "配置版本过低: 需要 $required_version, 当前 $current_version"
        return 1
    fi
    
    log_debug "配置版本验证通过: $current_version >= $required_version"
    return 0
}

# 版本号比较
version_compare() {
    local v1="$1"
    local v2="$2"
    
    # 将版本号转换为数组
    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"
    
    # 逐个比较
    for i in "${!v1_parts[@]}"; do
        local num1=${v1_parts[i]}
        local num2=${v2_parts[i]:-0}
        
        if [ $num1 -gt $num2 ]; then
            echo 1
            return
        elif [ $num1 -lt $num2 ]; then
            echo -1
            return
        fi
    done
    
    echo 0
}

# 创建示例迁移脚本
create_example_migrations() {
    # 示例：1.0.0 到 2.0.0 的迁移
    if [ ! -f "$CONFIG_MIGRATIONS_DIR/migration_1_0_0_to_2_0_0.sh" ]; then
        create_migration "1.0.0" "2.0.0" "example_migration"
    fi
}

# 导出函数
export -f init_config_versioning get_config_version set_config_version
export -f backup_config cleanup_old_backups create_config_version
export -f get_config_version_info list_config_versions rollback_config_version
export -f create_migration run_migration validate_config_version version_compare
export CONFIG_VERSION_ENABLED CONFIG_VERSION_DIR CONFIG_BACKUP_COUNT
export CONFIG_AUTO_BACKUP CONFIG_MIGRATION_ENABLED CONFIG_VERSION_FORMAT
export CONFIG_CURRENT_VERSION_FILE CONFIG_VERSION_SCHEMA CONFIG_MIGRATIONS_DIR