#!/bin/bash

# =============================================================================
# lint.sh - 代码质量检查脚本
# =============================================================================
# 运行 ShellCheck 检查所有 shell 脚本
#
# 用法:
#   ./scripts/lint.sh           # 检查所有脚本
#   ./scripts/lint.sh --fix     # 显示修复建议
#   ./scripts/lint.sh --ci      # CI 模式，输出 JSON 格式
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检查 shellcheck 是否安装
check_shellcheck() {
    if ! command -v shellcheck &>/dev/null; then
        echo -e "${RED}错误: ShellCheck 未安装${NC}"
        echo ""
        echo "安装方法:"
        echo "  Ubuntu/Debian: sudo apt install shellcheck"
        echo "  macOS:         brew install shellcheck"
        echo "  Termux:        pkg install shellcheck"
        echo ""
        exit 1
    fi

    echo -e "${GREEN}✓${NC} ShellCheck 版本: $(shellcheck --version | head -2 | tail -1)"
}

# 查找所有 shell 脚本
find_scripts() {
    find "$PROJECT_ROOT" \
        -type f \
        -name "*.sh" \
        ! -path "*/.git/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/vendor/*" \
        | sort
}

# 运行检查
run_lint() {
    local mode="${1:-default}"
    local scripts
    local failed=0
    local passed=0
    local total=0

    scripts=$(find_scripts)

    echo ""
    echo -e "${BLUE}=== ShellCheck 代码质量检查 ===${NC}"
    echo ""

    for script in $scripts; do
        ((total++))
        local relative_path="${script#$PROJECT_ROOT/}"

        case "$mode" in
            ci)
                # CI 模式：输出 JSON 格式
                if ! shellcheck -f json "$script" 2>/dev/null; then
                    ((failed++))
                else
                    ((passed++))
                fi
                ;;
            fix)
                # 修复建议模式
                echo -e "${BLUE}检查:${NC} $relative_path"
                if ! shellcheck -f diff "$script" 2>/dev/null; then
                    ((failed++))
                else
                    echo -e "  ${GREEN}✓ 无问题${NC}"
                    ((passed++))
                fi
                echo ""
                ;;
            *)
                # 默认模式
                printf "检查 %-50s " "$relative_path"
                if shellcheck -x "$script" >/dev/null 2>&1; then
                    echo -e "${GREEN}✓${NC}"
                    ((passed++))
                else
                    echo -e "${RED}✗${NC}"
                    ((failed++))
                    # 显示详细错误
                    shellcheck -x "$script" 2>&1 | head -20
                    echo ""
                fi
                ;;
        esac
    done

    echo ""
    echo -e "${BLUE}=== 检查结果 ===${NC}"
    echo -e "  总计:  $total 个脚本"
    echo -e "  ${GREEN}通过:  $passed${NC}"
    echo -e "  ${RED}失败:  $failed${NC}"
    echo ""

    if [[ $failed -gt 0 ]]; then
        echo -e "${YELLOW}提示: 使用 './scripts/lint.sh --fix' 查看修复建议${NC}"
        exit 1
    else
        echo -e "${GREEN}所有脚本通过检查！${NC}"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
用法: $0 [选项]

代码质量检查脚本

选项:
  --fix     显示修复建议（diff 格式）
  --ci      CI 模式，输出 JSON 格式
  -h, --help 显示此帮助信息

示例:
  $0                # 检查所有脚本
  $0 --fix          # 显示修复建议
  $0 --ci           # CI 集成模式

EOF
}

# 主函数
main() {
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --fix)
            check_shellcheck
            run_lint fix
            ;;
        --ci)
            check_shellcheck
            run_lint ci
            ;;
        "")
            check_shellcheck
            run_lint default
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
