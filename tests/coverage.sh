#!/bin/bash

# =============================================================================
# coverage.sh - 测试覆盖率检测脚本
# =============================================================================
# 分析测试覆盖的函数和脚本
#
# 用法:
#   ./tests/coverage.sh           # 生成覆盖率报告
#   ./tests/coverage.sh --html    # 生成 HTML 报告
#   ./tests/coverage.sh --detail  # 显示详细信息
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

# 输出目录
OUTPUT_DIR="${PROJECT_ROOT}/test-results/coverage"

# =============================================================================
# 辅助函数
# =============================================================================

# 提取脚本中的函数名
extract_functions() {
    local file="$1"
    grep -E '^\s*(function\s+)?[a-zA-Z_][a-zA-Z0-9_]*\s*\(\)\s*\{?' "$file" 2>/dev/null | \
        sed -E 's/^\s*(function\s+)?([a-zA-Z_][a-zA-Z0-9_]*)\s*\(\).*/\2/' | \
        sort -u
}

# 检查函数是否被测试覆盖
is_function_tested() {
    local func_name="$1"

    # 在测试文件中搜索函数调用
    grep -rq "$func_name" "$SCRIPT_DIR/unit" "$SCRIPT_DIR/integration" 2>/dev/null
}

# 获取脚本文件列表
get_script_files() {
    find "$PROJECT_ROOT/scripts" -name "*.sh" -type f 2>/dev/null
    find "$PROJECT_ROOT/lib" -name "*.sh" -type f 2>/dev/null
}

# 获取测试文件列表
get_test_files() {
    find "$SCRIPT_DIR" -name "test-*.sh" -type f 2>/dev/null
}

# =============================================================================
# 覆盖率分析
# =============================================================================

analyze_coverage() {
    local detail="${1:-false}"

    echo -e "${BLUE}=== 测试覆盖率分析 ===${NC}"
    echo ""

    local total_functions=0
    local covered_functions=0
    local total_scripts=0
    local covered_scripts=0

    # 脚本级别覆盖
    echo -e "${BLUE}--- 脚本覆盖情况 ---${NC}"
    printf "%-50s %s\n" "脚本文件" "状态"
    echo "------------------------------------------------------------"

    while IFS= read -r script; do
        [[ -z "$script" ]] && continue

        local script_name
        script_name=$(basename "$script")
        local test_file_pattern="test-${script_name%.sh}"

        ((total_scripts++))

        # 检查是否有对应的测试文件
        if find "$SCRIPT_DIR" -name "${test_file_pattern}*.sh" -type f 2>/dev/null | grep -q .; then
            printf "%-50s ${GREEN}✓ 已覆盖${NC}\n" "$script_name"
            ((covered_scripts++))
        else
            printf "%-50s ${YELLOW}○ 未覆盖${NC}\n" "$script_name"
        fi
    done < <(get_script_files)

    echo ""

    # 函数级别覆盖（如果启用详细模式）
    if [[ "$detail" == "true" ]]; then
        echo -e "${BLUE}--- 函数覆盖详情 ---${NC}"

        while IFS= read -r script; do
            [[ -z "$script" ]] && continue

            local script_name
            script_name=$(basename "$script")
            local functions
            functions=$(extract_functions "$script")

            if [[ -n "$functions" ]]; then
                echo ""
                echo -e "${BLUE}$script_name:${NC}"

                while IFS= read -r func; do
                    [[ -z "$func" ]] && continue
                    ((total_functions++))

                    if is_function_tested "$func"; then
                        printf "  ${GREEN}✓${NC} %s\n" "$func"
                        ((covered_functions++))
                    else
                        printf "  ${YELLOW}○${NC} %s\n" "$func"
                    fi
                done <<< "$functions"
            fi
        done < <(get_script_files)

        echo ""
    else
        # 简单统计函数
        while IFS= read -r script; do
            [[ -z "$script" ]] && continue

            local functions
            functions=$(extract_functions "$script")

            while IFS= read -r func; do
                [[ -z "$func" ]] && continue
                ((total_functions++))

                if is_function_tested "$func"; then
                    ((covered_functions++))
                fi
            done <<< "$functions"
        done < <(get_script_files)
    fi

    # 计算覆盖率
    local script_coverage=0
    local function_coverage=0

    if [[ $total_scripts -gt 0 ]]; then
        script_coverage=$(awk "BEGIN {printf \"%.1f\", ($covered_scripts/$total_scripts)*100}")
    fi

    if [[ $total_functions -gt 0 ]]; then
        function_coverage=$(awk "BEGIN {printf \"%.1f\", ($covered_functions/$total_functions)*100}")
    fi

    # 打印摘要
    echo -e "${BLUE}=== 覆盖率摘要 ===${NC}"
    echo ""
    echo "脚本覆盖率:"
    echo "  总脚本数:   $total_scripts"
    echo "  已覆盖:     $covered_scripts"
    echo "  覆盖率:     ${script_coverage}%"
    echo ""
    echo "函数覆盖率:"
    echo "  总函数数:   $total_functions"
    echo "  已覆盖:     $covered_functions"
    echo "  覆盖率:     ${function_coverage}%"
    echo ""

    # 评估
    if (( $(echo "$script_coverage >= 80" | bc -l) )); then
        echo -e "${GREEN}✓ 脚本覆盖率良好 (≥80%)${NC}"
    elif (( $(echo "$script_coverage >= 60" | bc -l) )); then
        echo -e "${YELLOW}△ 脚本覆盖率一般 (60-80%)${NC}"
    else
        echo -e "${RED}✗ 脚本覆盖率不足 (<60%)${NC}"
    fi

    if (( $(echo "$function_coverage >= 60" | bc -l) )); then
        echo -e "${GREEN}✓ 函数覆盖率良好 (≥60%)${NC}"
    elif (( $(echo "$function_coverage >= 40" | bc -l) )); then
        echo -e "${YELLOW}△ 函数覆盖率一般 (40-60%)${NC}"
    else
        echo -e "${RED}✗ 函数覆盖率不足 (<40%)${NC}"
    fi

    # 返回数据用于报告生成
    echo ""
    echo "COVERAGE_DATA:$total_scripts:$covered_scripts:$total_functions:$covered_functions"
}

# =============================================================================
# 生成 HTML 报告
# =============================================================================

generate_html_report() {
    mkdir -p "$OUTPUT_DIR"

    local report_file="$OUTPUT_DIR/coverage-report.html"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # 获取覆盖率数据
    local coverage_output
    coverage_output=$(analyze_coverage false 2>&1)

    local data_line
    data_line=$(echo "$coverage_output" | grep "^COVERAGE_DATA:" | tail -1)

    local total_scripts covered_scripts total_functions covered_functions
    IFS=':' read -r _ total_scripts covered_scripts total_functions covered_functions <<< "$data_line"

    local script_coverage function_coverage
    script_coverage=$(awk "BEGIN {printf \"%.1f\", ($covered_scripts/$total_scripts)*100}" 2>/dev/null || echo "0")
    function_coverage=$(awk "BEGIN {printf \"%.1f\", ($covered_functions/$total_functions)*100}" 2>/dev/null || echo "0")

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>测试覆盖率报告 - CI/CD Solution</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: #f5f5f5;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 10px;
            margin-bottom: 20px;
        }
        .header h1 { margin: 0 0 10px 0; }
        .header p { margin: 0; opacity: 0.9; }
        .card {
            background: white;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .metric {
            display: inline-block;
            text-align: center;
            padding: 20px 40px;
            margin: 10px;
            background: #f8f9fa;
            border-radius: 10px;
        }
        .metric-value {
            font-size: 48px;
            font-weight: bold;
        }
        .metric-label {
            color: #666;
            margin-top: 5px;
        }
        .good { color: #28a745; }
        .warning { color: #ffc107; }
        .bad { color: #dc3545; }
        .progress-bar {
            height: 20px;
            background: #e9ecef;
            border-radius: 10px;
            overflow: hidden;
            margin: 10px 0;
        }
        .progress-fill {
            height: 100%;
            transition: width 0.3s ease;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #eee;
        }
        th { background: #f8f9fa; }
        .status-covered { color: #28a745; }
        .status-uncovered { color: #ffc107; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 测试覆盖率报告</h1>
        <p>生成时间: ${timestamp}</p>
    </div>

    <div class="card">
        <h2>覆盖率概览</h2>
        <div class="metric">
            <div class="metric-value ${script_coverage%.*}" style="color: $([ "${script_coverage%.*}" -ge 80 ] && echo '#28a745' || echo '#ffc107')">${script_coverage}%</div>
            <div class="metric-label">脚本覆盖率</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${script_coverage}%; background: $([ "${script_coverage%.*}" -ge 80 ] && echo '#28a745' || echo '#ffc107')"></div>
            </div>
        </div>
        <div class="metric">
            <div class="metric-value" style="color: $([ "${function_coverage%.*}" -ge 60 ] && echo '#28a745' || echo '#ffc107')">${function_coverage}%</div>
            <div class="metric-label">函数覆盖率</div>
            <div class="progress-bar">
                <div class="progress-fill" style="width: ${function_coverage}%; background: $([ "${function_coverage%.*}" -ge 60 ] && echo '#28a745' || echo '#ffc107')"></div>
            </div>
        </div>
    </div>

    <div class="card">
        <h2>统计数据</h2>
        <table>
            <tr><th>指标</th><th>总数</th><th>已覆盖</th><th>覆盖率</th></tr>
            <tr>
                <td>脚本文件</td>
                <td>${total_scripts}</td>
                <td>${covered_scripts}</td>
                <td>${script_coverage}%</td>
            </tr>
            <tr>
                <td>函数</td>
                <td>${total_functions}</td>
                <td>${covered_functions}</td>
                <td>${function_coverage}%</td>
            </tr>
        </table>
    </div>

    <div class="card">
        <h2>测试文件</h2>
        <ul>
EOF

    # 添加测试文件列表
    while IFS= read -r test_file; do
        [[ -z "$test_file" ]] && continue
        local test_name
        test_name=$(basename "$test_file")
        echo "            <li>${test_name}</li>" >> "$report_file"
    done < <(get_test_files)

    cat >> "$report_file" << EOF
        </ul>
    </div>

    <div class="card">
        <p style="text-align: center; color: #666;">
            CI/CD Solution 测试覆盖率报告 | 自动生成
        </p>
    </div>
</body>
</html>
EOF

    echo -e "${GREEN}✓${NC} HTML 报告已生成: $report_file"
}

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    cat << EOF
用法: $0 [选项]

测试覆盖率检测脚本

选项:
  --detail    显示详细的函数覆盖信息
  --html      生成 HTML 格式报告
  -h, --help  显示此帮助信息

示例:
  $0                # 基本覆盖率分析
  $0 --detail       # 详细分析
  $0 --html         # 生成 HTML 报告

EOF
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --detail)
            analyze_coverage true
            ;;
        --html)
            analyze_coverage false
            generate_html_report
            ;;
        "")
            analyze_coverage false
            ;;
        *)
            echo -e "${RED}未知选项: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
