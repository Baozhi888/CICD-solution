#!/bin/bash

# =============================================================================
# config-merger.sh - 配置合并工具
# =============================================================================
# 合并多个 YAML 配置文件，支持环境覆盖和深度合并
#
# 用法:
#   ./scripts/config-merger.sh -b base.yaml -o overlay.yaml     # 合并两个文件
#   ./scripts/config-merger.sh -e production                     # 合并环境配置
#   ./scripts/config-merger.sh --diff base.yaml overlay.yaml     # 显示差异
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载颜色库
source "$SCRIPT_DIR/../lib/utils/colors.sh"

# =============================================================================
# 配置
# =============================================================================
BASE_CONFIG=""
OVERLAY_CONFIG=""
OUTPUT_FILE=""
ENVIRONMENT=""
CONFIG_DIR="${PROJECT_ROOT}/config"
SHOW_DIFF=false
DRY_RUN=false

# =============================================================================
# 辅助函数
# =============================================================================

# 检查 yq 是否安装
check_yq() {
    if ! command -v yq &>/dev/null; then
        print_error "yq 未安装，请先安装 yq"
        echo ""
        echo "安装方法:"
        echo "  Ubuntu/Debian: sudo apt install yq"
        echo "  macOS:         brew install yq"
        echo "  或从 https://github.com/mikefarah/yq 下载"
        exit 1
    fi
}

# 验证 YAML 文件
validate_yaml() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        print_error "文件不存在: $file"
        return 1
    fi

    if ! yq eval '.' "$file" &>/dev/null; then
        print_error "无效的 YAML 文件: $file"
        return 1
    fi

    return 0
}

# 深度合并两个 YAML 文件
# 使用 yq 的 merge 功能
merge_yaml() {
    local base="$1"
    local overlay="$2"
    local output="${3:--}"  # 默认输出到 stdout

    # 验证文件
    validate_yaml "$base" || return 1
    validate_yaml "$overlay" || return 1

    # 使用 yq 合并（overlay 覆盖 base）
    if [[ "$output" == "-" ]]; then
        yq eval-all '. as $item ireduce ({}; . * $item)' "$base" "$overlay"
    else
        yq eval-all '. as $item ireduce ({}; . * $item)' "$base" "$overlay" > "$output"
    fi
}

# 显示两个配置文件的差异
show_diff() {
    local base="$1"
    local overlay="$2"

    print_header "配置差异"

    # 验证文件
    validate_yaml "$base" || return 1
    validate_yaml "$overlay" || return 1

    echo -e "${COLOR_INFO}基础文件:${COLOR_NC} $base"
    echo -e "${COLOR_INFO}覆盖文件:${COLOR_NC} $overlay"
    echo ""

    # 获取所有键
    local base_keys overlay_keys

    base_keys=$(yq eval '.. | path | join(".")' "$base" 2>/dev/null | sort -u)
    overlay_keys=$(yq eval '.. | path | join(".")' "$overlay" 2>/dev/null | sort -u)

    # 找出新增的键
    echo -e "${COLOR_SUCCESS}新增的配置项:${COLOR_NC}"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! echo "$base_keys" | grep -q "^${key}$"; then
            local value
            value=$(yq eval ".$key" "$overlay" 2>/dev/null)
            echo -e "  ${COLOR_GREEN}+ $key${COLOR_NC}: $value"
        fi
    done <<< "$overlay_keys"
    echo ""

    # 找出修改的键
    echo -e "${COLOR_WARNING}修改的配置项:${COLOR_NC}"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if echo "$base_keys" | grep -q "^${key}$"; then
            local base_value overlay_value
            base_value=$(yq eval ".$key" "$base" 2>/dev/null)
            overlay_value=$(yq eval ".$key" "$overlay" 2>/dev/null)

            if [[ "$base_value" != "$overlay_value" ]]; then
                echo -e "  ${COLOR_YELLOW}~ $key${COLOR_NC}"
                echo -e "    ${COLOR_RED}- $base_value${COLOR_NC}"
                echo -e "    ${COLOR_GREEN}+ $overlay_value${COLOR_NC}"
            fi
        fi
    done <<< "$overlay_keys"
    echo ""

    # 找出删除的键（在 overlay 中不存在）
    echo -e "${COLOR_ERROR}缺失的配置项 (仅在基础文件中):${COLOR_NC}"
    while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if ! echo "$overlay_keys" | grep -q "^${key}$"; then
            local value
            value=$(yq eval ".$key" "$base" 2>/dev/null)
            echo -e "  ${COLOR_RED}- $key${COLOR_NC}: $value"
        fi
    done <<< "$base_keys"
}

# 合并环境配置
merge_environment() {
    local env="$1"
    local base_file="${CONFIG_DIR}/central-config.yaml"
    local env_file="${CONFIG_DIR}/environment/${env}.yaml"

    if [[ ! -f "$base_file" ]]; then
        print_error "基础配置文件不存在: $base_file"
        return 1
    fi

    if [[ ! -f "$env_file" ]]; then
        print_error "环境配置文件不存在: $env_file"
        return 1
    fi

    print_info "合并环境配置: $env"
    print_info "基础文件: $base_file"
    print_info "环境文件: $env_file"
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        print_warning "预览模式 - 不会写入文件"
        echo ""
        merge_yaml "$base_file" "$env_file"
    elif [[ -n "$OUTPUT_FILE" ]]; then
        merge_yaml "$base_file" "$env_file" "$OUTPUT_FILE"
        print_success "已合并到: $OUTPUT_FILE"
    else
        merge_yaml "$base_file" "$env_file"
    fi
}

# 合并多个配置文件
merge_multiple() {
    local files=("$@")
    local result_file

    if [[ ${#files[@]} -lt 2 ]]; then
        print_error "至少需要两个文件进行合并"
        return 1
    fi

    print_info "合并 ${#files[@]} 个配置文件..."

    # 创建临时文件
    result_file=$(mktemp)
    cp "${files[0]}" "$result_file"

    for ((i=1; i<${#files[@]}; i++)); do
        local temp_result
        temp_result=$(mktemp)
        merge_yaml "$result_file" "${files[$i]}" "$temp_result"
        mv "$temp_result" "$result_file"
        print_info "  + ${files[$i]}"
    done

    if [[ "$DRY_RUN" == true ]]; then
        cat "$result_file"
        rm -f "$result_file"
    elif [[ -n "$OUTPUT_FILE" ]]; then
        mv "$result_file" "$OUTPUT_FILE"
        print_success "已合并到: $OUTPUT_FILE"
    else
        cat "$result_file"
        rm -f "$result_file"
    fi
}

# 验证合并结果
validate_merged() {
    local file="$1"

    print_header "验证合并结果"

    if ! validate_yaml "$file"; then
        return 1
    fi

    print_success "YAML 格式有效"

    # 检查必需字段
    local required_fields=("project" "build" "test" "deploy")
    local missing=()

    for field in "${required_fields[@]}"; do
        if [[ $(yq eval ".$field" "$file" 2>/dev/null) == "null" ]]; then
            missing+=("$field")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        print_warning "缺少推荐字段: ${missing[*]}"
    else
        print_success "所有推荐字段都存在"
    fi

    # 显示配置摘要
    echo ""
    echo -e "${COLOR_BOLD}配置摘要:${COLOR_NC}"

    local project_name project_version
    project_name=$(yq eval '.project.name // "未设置"' "$file" 2>/dev/null)
    project_version=$(yq eval '.project.version // "未设置"' "$file" 2>/dev/null)

    echo "  项目名称: $project_name"
    echo "  项目版本: $project_version"

    local build_tool
    build_tool=$(yq eval '.build.tool // "未设置"' "$file" 2>/dev/null)
    echo "  构建工具: $build_tool"

    local deploy_target
    deploy_target=$(yq eval '.deploy.target // "未设置"' "$file" 2>/dev/null)
    echo "  部署目标: $deploy_target"
}

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    cat << EOF
用法: $0 [选项]

配置合并工具 - 合并多个 YAML 配置文件

选项:
  -b, --base FILE       基础配置文件
  -o, --overlay FILE    覆盖配置文件（可多次指定）
  -e, --env ENV         合并环境配置
  -O, --output FILE     输出文件（默认输出到 stdout）
  -d, --diff            显示配置差异
  -n, --dry-run         预览模式，不写入文件
  -v, --validate FILE   验证合并后的配置文件
  -h, --help            显示此帮助信息

合并规则:
  - 覆盖文件中的值会覆盖基础文件中的值
  - 数组会被完全替换（非追加）
  - 嵌套对象会进行深度合并

示例:
  # 合并两个配置文件
  $0 -b base.yaml -o overlay.yaml -O merged.yaml

  # 合并环境配置
  $0 -e production -O config/production.merged.yaml

  # 显示配置差异
  $0 --diff base.yaml overlay.yaml

  # 合并多个文件
  $0 -b base.yaml -o dev.yaml -o local.yaml -O merged.yaml

  # 预览合并结果
  $0 -b base.yaml -o overlay.yaml --dry-run

EOF
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    check_yq

    local overlay_files=()

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -b|--base)
                BASE_CONFIG="$2"
                shift 2
                ;;
            -o|--overlay)
                overlay_files+=("$2")
                shift 2
                ;;
            -e|--env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            -O|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -d|--diff)
                SHOW_DIFF=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--validate)
                validate_merged "$2"
                exit $?
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # 处理环境合并
    if [[ -n "$ENVIRONMENT" ]]; then
        merge_environment "$ENVIRONMENT"
        exit 0
    fi

    # 处理差异显示
    if [[ "$SHOW_DIFF" == true ]]; then
        if [[ -z "$BASE_CONFIG" ]] || [[ ${#overlay_files[@]} -eq 0 ]]; then
            print_error "显示差异需要指定基础文件和覆盖文件"
            exit 1
        fi
        show_diff "$BASE_CONFIG" "${overlay_files[0]}"
        exit 0
    fi

    # 处理文件合并
    if [[ -z "$BASE_CONFIG" ]]; then
        print_error "请指定基础配置文件 (-b)"
        show_help
        exit 1
    fi

    if [[ ${#overlay_files[@]} -eq 0 ]]; then
        print_error "请指定至少一个覆盖文件 (-o)"
        show_help
        exit 1
    fi

    # 执行合并
    if [[ ${#overlay_files[@]} -eq 1 ]]; then
        print_header "配置合并"
        print_info "基础文件: $BASE_CONFIG"
        print_info "覆盖文件: ${overlay_files[0]}"
        echo ""

        if [[ "$DRY_RUN" == true ]]; then
            print_warning "预览模式 - 不会写入文件"
            echo ""
            merge_yaml "$BASE_CONFIG" "${overlay_files[0]}"
        elif [[ -n "$OUTPUT_FILE" ]]; then
            merge_yaml "$BASE_CONFIG" "${overlay_files[0]}" "$OUTPUT_FILE"
            print_success "已合并到: $OUTPUT_FILE"
            echo ""
            validate_merged "$OUTPUT_FILE"
        else
            merge_yaml "$BASE_CONFIG" "${overlay_files[0]}"
        fi
    else
        merge_multiple "$BASE_CONFIG" "${overlay_files[@]}"
    fi
}

main "$@"
