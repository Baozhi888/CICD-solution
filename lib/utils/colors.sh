#!/bin/bash

# =============================================================================
# colors.sh - 统一颜色定义库
# =============================================================================
# 提供终端颜色输出的统一定义，避免各脚本重复定义
#
# 使用方法:
#   source "path/to/colors.sh"
#   echo -e "${COLOR_RED}Error message${COLOR_NC}"
#   print_success "Operation completed"
#
# =============================================================================

# 防止重复加载
if [[ -n "${_COLORS_LOADED:-}" ]]; then
    return 0
fi
_COLORS_LOADED=1

# =============================================================================
# 基础颜色定义
# =============================================================================

# 检测终端是否支持颜色
_supports_color() {
    # 检查 NO_COLOR 环境变量（https://no-color.org/）
    [[ -n "${NO_COLOR:-}" ]] && return 1

    # 检查是否为 tty
    [[ -t 1 ]] || return 1

    # 检查 TERM 是否支持颜色
    case "${TERM:-}" in
        xterm*|rxvt*|vt100*|screen*|tmux*|linux*|cygwin*|ansi*)
            return 0
            ;;
        *)
            # 检查 tput 是否可用
            command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null) -ge 8 ]]
            ;;
    esac
}

# 根据终端能力设置颜色
if _supports_color; then
    # 基础颜色
    COLOR_BLACK='\033[0;30m'
    COLOR_RED='\033[0;31m'
    COLOR_GREEN='\033[0;32m'
    COLOR_YELLOW='\033[1;33m'
    COLOR_BLUE='\033[0;34m'
    COLOR_MAGENTA='\033[0;35m'
    COLOR_CYAN='\033[0;36m'
    COLOR_WHITE='\033[0;37m'

    # 粗体颜色
    COLOR_BOLD_BLACK='\033[1;30m'
    COLOR_BOLD_RED='\033[1;31m'
    COLOR_BOLD_GREEN='\033[1;32m'
    COLOR_BOLD_YELLOW='\033[1;33m'
    COLOR_BOLD_BLUE='\033[1;34m'
    COLOR_BOLD_MAGENTA='\033[1;35m'
    COLOR_BOLD_CYAN='\033[1;36m'
    COLOR_BOLD_WHITE='\033[1;37m'

    # 背景颜色
    COLOR_BG_BLACK='\033[40m'
    COLOR_BG_RED='\033[41m'
    COLOR_BG_GREEN='\033[42m'
    COLOR_BG_YELLOW='\033[43m'
    COLOR_BG_BLUE='\033[44m'
    COLOR_BG_MAGENTA='\033[45m'
    COLOR_BG_CYAN='\033[46m'
    COLOR_BG_WHITE='\033[47m'

    # 样式
    COLOR_BOLD='\033[1m'
    COLOR_DIM='\033[2m'
    COLOR_ITALIC='\033[3m'
    COLOR_UNDERLINE='\033[4m'
    COLOR_BLINK='\033[5m'
    COLOR_REVERSE='\033[7m'
    COLOR_HIDDEN='\033[8m'
    COLOR_STRIKETHROUGH='\033[9m'

    # 重置
    COLOR_NC='\033[0m'
    COLOR_RESET='\033[0m'
else
    # 不支持颜色时设置为空
    COLOR_BLACK=''
    COLOR_RED=''
    COLOR_GREEN=''
    COLOR_YELLOW=''
    COLOR_BLUE=''
    COLOR_MAGENTA=''
    COLOR_CYAN=''
    COLOR_WHITE=''

    COLOR_BOLD_BLACK=''
    COLOR_BOLD_RED=''
    COLOR_BOLD_GREEN=''
    COLOR_BOLD_YELLOW=''
    COLOR_BOLD_BLUE=''
    COLOR_BOLD_MAGENTA=''
    COLOR_BOLD_CYAN=''
    COLOR_BOLD_WHITE=''

    COLOR_BG_BLACK=''
    COLOR_BG_RED=''
    COLOR_BG_GREEN=''
    COLOR_BG_YELLOW=''
    COLOR_BG_BLUE=''
    COLOR_BG_MAGENTA=''
    COLOR_BG_CYAN=''
    COLOR_BG_WHITE=''

    COLOR_BOLD=''
    COLOR_DIM=''
    COLOR_ITALIC=''
    COLOR_UNDERLINE=''
    COLOR_BLINK=''
    COLOR_REVERSE=''
    COLOR_HIDDEN=''
    COLOR_STRIKETHROUGH=''

    COLOR_NC=''
    COLOR_RESET=''
fi

# =============================================================================
# 语义化颜色别名
# =============================================================================
COLOR_ERROR="${COLOR_RED}"
COLOR_SUCCESS="${COLOR_GREEN}"
COLOR_WARNING="${COLOR_YELLOW}"
COLOR_INFO="${COLOR_BLUE}"
COLOR_DEBUG="${COLOR_CYAN}"
COLOR_HIGHLIGHT="${COLOR_BOLD_WHITE}"

# =============================================================================
# 便捷输出函数
# =============================================================================

# 打印成功消息
print_success() {
    echo -e "${COLOR_SUCCESS}✓${COLOR_NC} $*"
}

# 打印错误消息
print_error() {
    echo -e "${COLOR_ERROR}✗${COLOR_NC} $*" >&2
}

# 打印警告消息
print_warning() {
    echo -e "${COLOR_WARNING}⚠${COLOR_NC} $*" >&2
}

# 打印信息消息
print_info() {
    echo -e "${COLOR_INFO}ℹ${COLOR_NC} $*"
}

# 打印调试消息（仅在 DEBUG=1 时显示）
print_debug() {
    [[ "${DEBUG:-0}" == "1" ]] && echo -e "${COLOR_DEBUG}⊙${COLOR_NC} $*" >&2
}

# 打印带时间戳的消息
print_timestamped() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case "$level" in
        success) echo -e "${COLOR_DIM}[${timestamp}]${COLOR_NC} ${COLOR_SUCCESS}✓${COLOR_NC} $*" ;;
        error)   echo -e "${COLOR_DIM}[${timestamp}]${COLOR_NC} ${COLOR_ERROR}✗${COLOR_NC} $*" >&2 ;;
        warning) echo -e "${COLOR_DIM}[${timestamp}]${COLOR_NC} ${COLOR_WARNING}⚠${COLOR_NC} $*" >&2 ;;
        info)    echo -e "${COLOR_DIM}[${timestamp}]${COLOR_NC} ${COLOR_INFO}ℹ${COLOR_NC} $*" ;;
        *)       echo -e "${COLOR_DIM}[${timestamp}]${COLOR_NC} $*" ;;
    esac
}

# 打印分隔线
print_separator() {
    local char="${1:--}"
    local width="${2:-80}"
    printf '%*s\n' "$width" '' | tr ' ' "$char"
}

# 打印标题
print_header() {
    local title="$1"
    local width="${2:-80}"
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    print_separator "=" "$width"
    printf "%*s %s %*s\n" "$padding" "" "${COLOR_BOLD}${title}${COLOR_NC}" "$padding" ""
    print_separator "=" "$width"
    echo ""
}

# 打印进度点
print_progress() {
    echo -n "."
}

# 打印完成状态
print_done() {
    echo -e " ${COLOR_SUCCESS}done${COLOR_NC}"
}

# =============================================================================
# 兼容性别名（向后兼容旧代码）
# =============================================================================
# 这些别名允许现有代码继续工作，同时鼓励使用新的 COLOR_ 前缀

# 为旧的 LOG_ 前缀提供别名
LOG_RED="${COLOR_RED}"
LOG_GREEN="${COLOR_GREEN}"
LOG_YELLOW="${COLOR_YELLOW}"
LOG_BLUE="${COLOR_BLUE}"
LOG_NC="${COLOR_NC}"

# 为旧的 GEN_ 前缀提供别名
GEN_RED="${COLOR_RED}"
GEN_GREEN="${COLOR_GREEN}"
GEN_YELLOW="${COLOR_YELLOW}"
GEN_BLUE="${COLOR_BLUE}"
GEN_NC="${COLOR_NC}"

# 为旧的 VAL_ 前缀提供别名
VAL_RED="${COLOR_RED}"
VAL_GREEN="${COLOR_GREEN}"
VAL_YELLOW="${COLOR_YELLOW}"
VAL_BLUE="${COLOR_BLUE}"
VAL_NC="${COLOR_NC}"

# 为旧的 CFG_ 前缀提供别名
CFG_RED="${COLOR_RED}"
CFG_GREEN="${COLOR_GREEN}"
CFG_YELLOW="${COLOR_YELLOW}"
CFG_BLUE="${COLOR_BLUE}"
CFG_NC="${COLOR_NC}"
