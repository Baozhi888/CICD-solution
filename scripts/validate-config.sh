#!/bin/bash

# 配置验证脚本
# 用于在CI/CD流程执行前检查配置的正确性

# 颜色定义
VAL_RED='\033[0;31m'
VAL_GREEN='\033[0;32m'
VAL_YELLOW='\033[1;33m'
VAL_BLUE='\033[0;34m'
VAL_NC='\033[0m' # No Color

# 日志函数
val_log_debug() {
    if [ "${VAL_LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        echo -e "${VAL_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [VALIDATE DEBUG]${VAL_NC} $1" >&2
    fi
}

val_log_info() {
    echo -e "${VAL_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [VALIDATE INFO]${VAL_NC} $1" >&2
}

val_log_warn() {
    echo -e "${VAL_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [VALIDATE WARN]${VAL_NC} $1" >&2
}

val_log_error() {
    echo -e "${VAL_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [VALIDATE ERROR]${VAL_NC} $1" >&2
}

# 默认参数
VAL_CONFIG_FILE="/root/idear/cicd-solution/config/central-config.yaml"
VAL_SCHEMA_FILE="/root/idear/cicd-solution/config/config-schema.json"
VAL_STRICT_MODE=false
VAL_ENV_CONFIG_DIR="/root/idear/cicd-solution/config/environment"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

配置验证脚本

选项:
  -c, --config FILE        配置文件路径 [默认: $VAL_CONFIG_FILE]
  -s, --schema FILE        配置模式文件路径 [默认: $VAL_SCHEMA_FILE]
  -e, --env ENV            环境名称 (将验证对应环境配置文件)
  -t, --strict             严格模式，遇到警告也退出
  -h, --help               显示此帮助信息

示例:
  $0 -c ./config.yaml
  $0 --config /path/to/config.yml --strict
  $0 -e production

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            VAL_CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--schema)
            VAL_SCHEMA_FILE="$2"
            shift 2
            ;;
        -e|--env)
            VAL_ENV_NAME="$2"
            shift 2
            ;;
        -t|--strict)
            VAL_STRICT_MODE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            val_log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必要命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        val_log_error "缺少必要命令: $1"
        exit 1
    fi
}

# 验证YAML文件格式
validate_yaml_format() {
    local yaml_file="$1"
    
    val_log_info "验证YAML格式: $yaml_file"
    
    # 检查yq命令是否存在
    check_command "yq"
    
    # 尝试解析YAML文件
    if yq eval '.' "$yaml_file" &> /dev/null; then
        val_log_info "YAML格式验证通过: $yaml_file"
        return 0
    else
        val_log_error "YAML格式验证失败: $yaml_file"
        return 1
    fi
}

# 验证配置文件结构
validate_config_structure() {
    local config_file="$1"
    local schema_file="$2"
    
    val_log_info "验证配置文件结构: $config_file"
    
    # 如果提供了模式文件，则使用模式验证
    if [ -f "$schema_file" ]; then
        # 检查是否有可用的模式验证工具
        if command -v ajv &> /dev/null; then
            # 转换YAML到JSON
            local json_file=$(mktemp)
            yq eval -o=json "$config_file" > "$json_file"
            
            # 执行模式验证
            if ajv validate -s "$schema_file" -d "$json_file"; then
                val_log_info "配置文件结构验证通过: $config_file"
                rm -f "$json_file"
                return 0
            else
                val_log_error "配置文件结构验证失败: $config_file"
                rm -f "$json_file"
                return 1
            fi
        else
            val_log_warn "缺少ajv命令，跳过模式验证"
        fi
    else
        val_log_warn "模式文件不存在，跳过结构验证: $schema_file"
    fi
    
    # 基本结构验证
    local required_sections=("global" "build" "test" "deploy" "rollback")
    local missing_sections=()
    
    for section in "${required_sections[@]}"; do
        if ! yq eval ".$section" "$config_file" &> /dev/null; then
            missing_sections+=("$section")
        fi
    done
    
    if [ ${#missing_sections[@]} -gt 0 ]; then
        val_log_error "配置文件缺少必需的章节: ${missing_sections[*]}"
        return 1
    fi
    
    val_log_info "基本配置文件结构验证通过: $config_file"
    return 0
}

# 验证必需配置项
validate_required_configs() {
    local config_file="$1"
    
    val_log_info "验证必需配置项: $config_file"
    
    # 定义必需配置项
    local required_configs=(
        "global.log_level"
        "global.timezone"
        "build.default_build_dir"
        "build.default_output_dir"
        "test.default_test_type"
        "deploy.default_target"
        "deploy.default_strategy"
    )
    
    local missing_configs=()
    
    for config in "${required_configs[@]}"; do
        if ! yq eval ".$config" "$config_file" &> /dev/null; then
            missing_configs+=("$config")
        fi
    done
    
    if [ ${#missing_configs[@]} -gt 0 ]; then
        val_log_error "配置文件缺少必需的配置项: ${missing_configs[*]}"
        return 1
    fi
    
    val_log_info "必需配置项验证通过: $config_file"
    return 0
}

# 验证配置值范围
validate_config_ranges() {
    local config_file="$1"
    
    val_log_info "验证配置值范围: $config_file"
    
    # 验证超时设置
    local timeout=$(yq eval '.global.timeout' "$config_file")
    if [[ $timeout =~ ^[0-9]+$ ]] && [ "$timeout" -lt 1 ]; then
        val_log_error "全局超时设置无效: $timeout (应大于0)"
        return 1
    fi
    
    # 验证重试次数
    local retry_count=$(yq eval '.global.retry_count' "$config_file")
    if [[ $retry_count =~ ^[0-9]+$ ]] && [ "$retry_count" -lt 0 ]; then
        val_log_error "重试次数设置无效: $retry_count (应大于等于0)"
        return 1
    fi
    
    # 验证副本数量
    local replicas=$(yq eval '.deploy.default_replicas' "$config_file")
    if [[ $replicas =~ ^[0-9]+$ ]] && [ "$replicas" -lt 1 ]; then
        val_log_error "默认副本数量设置无效: $replicas (应大于0)"
        return 1
    fi
    
    # 验证测试覆盖率阈值
    local coverage_threshold=$(yq eval '.test.coverage_threshold' "$config_file")
    if [[ $coverage_threshold =~ ^[0-9]+$ ]] && ([ "$coverage_threshold" -lt 0 ] || [ "$coverage_threshold" -gt 100 ]); then
        val_log_error "测试覆盖率阈值设置无效: $coverage_threshold (应在0-100之间)"
        return 1
    fi
    
    val_log_info "配置值范围验证通过: $config_file"
    return 0
}

# 验证路径配置
validate_path_configs() {
    local config_file="$1"
    
    val_log_info "验证路径配置: $config_file"
    
    # 检查kubectl路径
    local kubectl_path=$(yq eval '.deploy.kubernetes.kubectl_path' "$config_file")
    if [ -n "$kubectl_path" ] && [ "$kubectl_path" != "kubectl" ] && ! command -v "$kubectl_path" &> /dev/null; then
        val_log_warn "kubectl路径不存在: $kubectl_path"
        if [ "$VAL_STRICT_MODE" = true ]; then
            return 1
        fi
    fi
    
    # 检查docker路径
    local docker_path=$(yq eval '.deploy.docker.docker_path' "$config_file")
    if [ -n "$docker_path" ] && [ "$docker_path" != "docker" ] && ! command -v "$docker_path" &> /dev/null; then
        val_log_warn "docker路径不存在: $docker_path"
        if [ "$VAL_STRICT_MODE" = true ]; then
            return 1
        fi
    fi
    
    # 检查docker-compose路径
    local docker_compose_path=$(yq eval '.deploy.docker.docker_compose_path' "$config_file")
    if [ -n "$docker_compose_path" ] && [ "$docker_compose_path" != "docker-compose" ] && ! command -v "$docker_compose_path" &> /dev/null; then
        val_log_warn "docker-compose路径不存在: $docker_compose_path"
        if [ "$VAL_STRICT_MODE" = true ]; then
            return 1
        fi
    fi
    
    val_log_info "路径配置验证完成: $config_file"
    return 0
}

# 验证环境配置文件
validate_env_config() {
    local env_name="$1"
    local env_config_file="$VAL_ENV_CONFIG_DIR/${env_name}.yaml"
    
    val_log_info "验证环境配置文件: $env_config_file"
    
    # 检查环境配置文件是否存在
    if [ ! -f "$env_config_file" ]; then
        val_log_error "环境配置文件不存在: $env_config_file"
        return 1
    fi
    
    # 验证YAML格式
    if ! validate_yaml_format "$env_config_file"; then
        return 1
    fi
    
    # 验证配置文件结构
    if ! validate_config_structure "$env_config_file" "$VAL_SCHEMA_FILE"; then
        return 1
    fi
    
    # 验证必需配置项
    if ! validate_required_configs "$env_config_file"; then
        return 1
    fi
    
    # 验证配置值范围
    if ! validate_config_ranges "$env_config_file"; then
        return 1
    fi
    
    val_log_info "环境配置文件验证通过: $env_config_file"
    return 0
}

# 主验证流程
main() {
    val_log_info "开始执行配置验证流程"
    val_log_info "配置文件: $VAL_CONFIG_FILE"
    val_log_info "严格模式: $VAL_STRICT_MODE"
    
    # 检查配置文件是否存在
    if [ ! -f "$VAL_CONFIG_FILE" ]; then
        val_log_error "配置文件不存在: $VAL_CONFIG_FILE"
        exit 1
    fi
    
    # 执行各项验证
    local validation_errors=0
    
    # 验证YAML格式
    if ! validate_yaml_format "$VAL_CONFIG_FILE"; then
        ((validation_errors++))
    fi
    
    # 验证配置文件结构
    if ! validate_config_structure "$VAL_CONFIG_FILE" "$VAL_SCHEMA_FILE"; then
        ((validation_errors++))
    fi
    
    # 验证必需配置项
    if ! validate_required_configs "$VAL_CONFIG_FILE"; then
        ((validation_errors++))
    fi
    
    # 验证配置值范围
    if ! validate_config_ranges "$VAL_CONFIG_FILE"; then
        ((validation_errors++))
    fi
    
    # 验证路径配置
    if ! validate_path_configs "$VAL_CONFIG_FILE"; then
        ((validation_errors++))
    fi
    
    # 如果指定了环境，验证环境配置文件
    if [ -n "$VAL_ENV_NAME" ]; then
        if ! validate_env_config "$VAL_ENV_NAME"; then
            ((validation_errors++))
        fi
    fi
    
    # 检查验证结果
    if [ $validation_errors -gt 0 ]; then
        val_log_error "配置验证失败，发现 $validation_errors 个错误"
        exit 1
    else
        val_log_info "配置验证通过"
    fi
    
    val_log_info "配置验证流程完成"
}

# 执行主函数
main "$@"