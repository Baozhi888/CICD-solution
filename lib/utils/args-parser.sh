#!/bin/bash

# =============================================================================
# args-parser.sh - 统一参数解析库
# =============================================================================
# 提供通用的命令行参数解析功能，支持短选项、长选项和位置参数
#
# 使用方法:
#   source "path/to/args-parser.sh"
#
#   # 定义选项
#   args_define_option "-v" "--verbose" "VERBOSE" "false" "启用详细输出"
#   args_define_option "-c" "--config" "CONFIG_FILE" "" "配置文件路径"
#   args_define_option "-e" "--env" "ENVIRONMENT" "development" "环境名称"
#
#   # 解析参数
#   args_parse "$@"
#
#   # 使用解析结果
#   if [[ "$VERBOSE" == "true" ]]; then
#       echo "详细模式已启用"
#   fi
#
# =============================================================================

# 防止重复加载
if [[ -n "${_ARGS_PARSER_LOADED:-}" ]]; then
    return 0
fi
_ARGS_PARSER_LOADED=1

# =============================================================================
# 内部变量
# =============================================================================
declare -a _ARGS_SHORT_OPTS=()      # 短选项列表
declare -a _ARGS_LONG_OPTS=()       # 长选项列表
declare -a _ARGS_VAR_NAMES=()       # 变量名列表
declare -a _ARGS_DEFAULTS=()        # 默认值列表
declare -a _ARGS_DESCRIPTIONS=()    # 描述列表
declare -a _ARGS_HAS_VALUE=()       # 是否需要值
declare -a _ARGS_POSITIONAL=()      # 位置参数
declare -a _ARGS_REMAINING=()       # 剩余参数

_ARGS_SCRIPT_NAME=""                # 脚本名称
_ARGS_SCRIPT_DESC=""                # 脚本描述
_ARGS_VERSION=""                    # 版本号

# =============================================================================
# 公共函数
# =============================================================================

# 设置脚本基本信息
# 用法: args_set_info "脚本名称" "脚本描述" "版本号"
args_set_info() {
    _ARGS_SCRIPT_NAME="${1:-$(basename "$0")}"
    _ARGS_SCRIPT_DESC="${2:-}"
    _ARGS_VERSION="${3:-1.0.0}"
}

# 定义一个选项
# 用法: args_define_option "-v" "--verbose" "VERBOSE" "false" "启用详细输出"
# 参数:
#   $1 - 短选项 (如 "-v")，可为空
#   $2 - 长选项 (如 "--verbose")，可为空
#   $3 - 变量名
#   $4 - 默认值（空字符串表示必填，"__FLAG__" 表示布尔标志）
#   $5 - 描述
args_define_option() {
    local short_opt="$1"
    local long_opt="$2"
    local var_name="$3"
    local default_val="$4"
    local description="${5:-}"

    _ARGS_SHORT_OPTS+=("$short_opt")
    _ARGS_LONG_OPTS+=("$long_opt")
    _ARGS_VAR_NAMES+=("$var_name")
    _ARGS_DEFAULTS+=("$default_val")
    _ARGS_DESCRIPTIONS+=("$description")

    # 检测是否为布尔标志（默认值为 "true" 或 "false"）
    if [[ "$default_val" == "true" || "$default_val" == "false" ]]; then
        _ARGS_HAS_VALUE+=(0)
    else
        _ARGS_HAS_VALUE+=(1)
    fi

    # 设置默认值
    if [[ -n "$default_val" && "$default_val" != "__FLAG__" ]]; then
        eval "${var_name}='${default_val}'"
    fi
}

# 定义布尔标志选项（简化版）
# 用法: args_define_flag "-v" "--verbose" "VERBOSE" "启用详细输出"
args_define_flag() {
    local short_opt="$1"
    local long_opt="$2"
    local var_name="$3"
    local description="${4:-}"

    args_define_option "$short_opt" "$long_opt" "$var_name" "false" "$description"
}

# 解析命令行参数
# 用法: args_parse "$@"
args_parse() {
    local i opt found var_name has_value

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                args_show_help
                exit 0
                ;;
            --version)
                echo "${_ARGS_SCRIPT_NAME} ${_ARGS_VERSION}"
                exit 0
                ;;
            --)
                shift
                _ARGS_REMAINING+=("$@")
                break
                ;;
            -*)
                found=0
                for i in "${!_ARGS_SHORT_OPTS[@]}"; do
                    if [[ "$1" == "${_ARGS_SHORT_OPTS[$i]}" || "$1" == "${_ARGS_LONG_OPTS[$i]}" ]]; then
                        var_name="${_ARGS_VAR_NAMES[$i]}"
                        has_value="${_ARGS_HAS_VALUE[$i]}"

                        if [[ "$has_value" -eq 1 ]]; then
                            # 需要值的选项
                            if [[ -z "${2:-}" || "$2" == -* ]]; then
                                echo "错误: 选项 $1 需要一个参数" >&2
                                exit 1
                            fi
                            eval "${var_name}='$2'"
                            shift
                        else
                            # 布尔标志
                            eval "${var_name}='true'"
                        fi
                        found=1
                        break
                    fi
                done

                if [[ "$found" -eq 0 ]]; then
                    # 检查是否为合并的短选项（如 -vf）
                    if [[ "$1" =~ ^-[a-zA-Z]+$ ]]; then
                        local combined="${1:1}"
                        local char
                        for (( j=0; j<${#combined}; j++ )); do
                            char="${combined:$j:1}"
                            found=0
                            for i in "${!_ARGS_SHORT_OPTS[@]}"; do
                                if [[ "-$char" == "${_ARGS_SHORT_OPTS[$i]}" ]]; then
                                    var_name="${_ARGS_VAR_NAMES[$i]}"
                                    eval "${var_name}='true'"
                                    found=1
                                    break
                                fi
                            done
                            if [[ "$found" -eq 0 ]]; then
                                echo "错误: 未知选项 -$char" >&2
                                exit 1
                            fi
                        done
                    else
                        echo "错误: 未知选项 $1" >&2
                        echo "使用 -h 或 --help 查看帮助" >&2
                        exit 1
                    fi
                fi
                ;;
            *)
                _ARGS_POSITIONAL+=("$1")
                ;;
        esac
        shift
    done

    # 验证必填参数
    _args_validate_required
}

# 获取位置参数
# 用法: args_get_positional 0  # 获取第一个位置参数
args_get_positional() {
    local index="$1"
    echo "${_ARGS_POSITIONAL[$index]:-}"
}

# 获取位置参数数量
args_positional_count() {
    echo "${#_ARGS_POSITIONAL[@]}"
}

# 获取所有位置参数
args_get_all_positional() {
    echo "${_ARGS_POSITIONAL[*]}"
}

# 获取剩余参数（-- 之后的参数）
args_get_remaining() {
    echo "${_ARGS_REMAINING[*]}"
}

# 显示帮助信息
args_show_help() {
    local i short long default desc

    echo ""
    echo "${_ARGS_SCRIPT_NAME}${_ARGS_VERSION:+ v${_ARGS_VERSION}}"
    [[ -n "$_ARGS_SCRIPT_DESC" ]] && echo "$_ARGS_SCRIPT_DESC"
    echo ""
    echo "用法: ${_ARGS_SCRIPT_NAME} [选项] [参数...]"
    echo ""
    echo "选项:"

    # 计算最长选项长度用于对齐
    local max_len=0
    for i in "${!_ARGS_SHORT_OPTS[@]}"; do
        short="${_ARGS_SHORT_OPTS[$i]}"
        long="${_ARGS_LONG_OPTS[$i]}"
        local opt_str=""
        [[ -n "$short" ]] && opt_str="$short"
        [[ -n "$short" && -n "$long" ]] && opt_str="$opt_str, "
        [[ -n "$long" ]] && opt_str="$opt_str$long"
        [[ "${_ARGS_HAS_VALUE[$i]}" -eq 1 ]] && opt_str="$opt_str <值>"
        [[ ${#opt_str} -gt $max_len ]] && max_len=${#opt_str}
    done
    max_len=$((max_len + 4))

    # 打印选项
    for i in "${!_ARGS_SHORT_OPTS[@]}"; do
        short="${_ARGS_SHORT_OPTS[$i]}"
        long="${_ARGS_LONG_OPTS[$i]}"
        default="${_ARGS_DEFAULTS[$i]}"
        desc="${_ARGS_DESCRIPTIONS[$i]}"

        local opt_str="  "
        [[ -n "$short" ]] && opt_str="$opt_str$short"
        [[ -n "$short" && -n "$long" ]] && opt_str="$opt_str, "
        [[ -n "$long" ]] && opt_str="$opt_str$long"
        [[ "${_ARGS_HAS_VALUE[$i]}" -eq 1 ]] && opt_str="$opt_str <值>"

        printf "%-${max_len}s %s" "$opt_str" "$desc"
        [[ -n "$default" && "$default" != "false" ]] && printf " [默认: %s]" "$default"
        echo ""
    done

    echo ""
    echo "  -h, --help          显示此帮助信息"
    echo "  --version           显示版本信息"
    echo ""
}

# 清除所有选项定义（用于测试或重新初始化）
args_reset() {
    _ARGS_SHORT_OPTS=()
    _ARGS_LONG_OPTS=()
    _ARGS_VAR_NAMES=()
    _ARGS_DEFAULTS=()
    _ARGS_DESCRIPTIONS=()
    _ARGS_HAS_VALUE=()
    _ARGS_POSITIONAL=()
    _ARGS_REMAINING=()
}

# =============================================================================
# 内部函数
# =============================================================================

# 验证必填参数
_args_validate_required() {
    local i var_name default

    for i in "${!_ARGS_VAR_NAMES[@]}"; do
        var_name="${_ARGS_VAR_NAMES[$i]}"
        default="${_ARGS_DEFAULTS[$i]}"

        # 如果默认值为空且变量未设置，则为必填参数
        if [[ -z "$default" ]]; then
            local current_val
            eval "current_val=\${${var_name}:-}"
            if [[ -z "$current_val" ]]; then
                local opt="${_ARGS_LONG_OPTS[$i]:-${_ARGS_SHORT_OPTS[$i]}}"
                echo "错误: 缺少必填参数 $opt" >&2
                exit 1
            fi
        fi
    done
}

# =============================================================================
# 便捷函数
# =============================================================================

# 检查是否启用了详细模式
args_is_verbose() {
    [[ "${VERBOSE:-false}" == "true" ]]
}

# 检查是否启用了调试模式
args_is_debug() {
    [[ "${DEBUG:-false}" == "true" ]]
}

# 打印详细信息（仅在详细模式下）
args_verbose() {
    args_is_verbose && echo "$@"
}

# 打印调试信息（仅在调试模式下）
args_debug() {
    args_is_debug && echo "[DEBUG] $@" >&2
}
