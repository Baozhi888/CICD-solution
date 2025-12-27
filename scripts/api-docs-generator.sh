#!/bin/bash

# =============================================================================
# api-docs-generator.sh - API 文档生成工具
# =============================================================================
# 从 shell 脚本中提取函数文档并生成 API 文档
#
# 用法:
#   ./scripts/api-docs-generator.sh                    # 生成所有文档
#   ./scripts/api-docs-generator.sh --format markdown  # 指定格式
#   ./scripts/api-docs-generator.sh --output docs/api  # 指定输出目录
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载颜色库
source "$SCRIPT_DIR/../lib/utils/colors.sh"

# =============================================================================
# 配置
# =============================================================================
OUTPUT_DIR="${PROJECT_ROOT}/docs/api"
OUTPUT_FORMAT="markdown"
INCLUDE_PRIVATE="false"

# =============================================================================
# 辅助函数
# =============================================================================

# 提取脚本头部注释
extract_script_header() {
    local file="$1"
    local in_header=false
    local header=""

    while IFS= read -r line; do
        if [[ "$line" =~ ^#! ]]; then
            continue
        elif [[ "$line" =~ ^#[[:space:]]*=+ ]]; then
            in_header=true
            continue
        elif [[ "$in_header" == true && "$line" =~ ^#[[:space:]]*=+ ]]; then
            break
        elif [[ "$in_header" == true && "$line" =~ ^# ]]; then
            header+="${line#\# }"$'\n'
        elif [[ ! "$line" =~ ^# ]]; then
            break
        fi
    done < "$file"

    echo "$header"
}

# 提取函数信息
extract_functions() {
    local file="$1"
    local functions=()

    # 使用 awk 提取函数定义和注释
    awk '
    BEGIN { in_comment = 0; comment = ""; }
    /^[[:space:]]*#/ {
        if (in_comment == 0) comment = "";
        in_comment = 1;
        gsub(/^[[:space:]]*#[[:space:]]?/, "");
        comment = comment $0 "\n";
        next;
    }
    /^[[:space:]]*(function[[:space:]]+)?[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{?/ {
        match($0, /[a-zA-Z_][a-zA-Z0-9_]*/);
        func_name = substr($0, RSTART, RLENGTH);
        if (func_name != "function") {
            print "FUNC:" func_name;
            if (comment != "") {
                gsub(/\n$/, "", comment);
                print "DOC:" comment;
            }
            comment = "";
        }
        in_comment = 0;
        next;
    }
    { in_comment = 0; comment = ""; }
    ' "$file"
}

# 解析函数文档
parse_function_doc() {
    local doc="$1"
    local description=""
    local params=()
    local returns=""
    local example=""

    local in_example=false

    while IFS= read -r line; do
        if [[ "$line" =~ ^@param ]]; then
            params+=("${line#@param }")
        elif [[ "$line" =~ ^@return ]]; then
            returns="${line#@return }"
        elif [[ "$line" =~ ^@example ]]; then
            in_example=true
        elif [[ "$in_example" == true ]]; then
            example+="$line"$'\n'
        else
            description+="$line"$'\n'
        fi
    done <<< "$doc"

    echo "DESC:${description}"
    for param in "${params[@]}"; do
        echo "PARAM:${param}"
    done
    echo "RETURN:${returns}"
    echo "EXAMPLE:${example}"
}

# =============================================================================
# 文档生成
# =============================================================================

# 生成 Markdown 文档
generate_markdown() {
    local file="$1"
    local output_file="$2"
    local filename
    filename=$(basename "$file")

    {
        echo "# ${filename%.sh} API 文档"
        echo ""
        echo "> 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""

        # 提取脚本头部
        local header
        header=$(extract_script_header "$file")
        if [[ -n "$header" ]]; then
            echo "## 概述"
            echo ""
            echo "$header"
            echo ""
        fi

        echo "## 函数列表"
        echo ""

        # 生成目录
        local func_name=""
        while IFS= read -r line; do
            if [[ "$line" =~ ^FUNC: ]]; then
                func_name="${line#FUNC:}"
                # 跳过私有函数（以 _ 开头）
                if [[ "$INCLUDE_PRIVATE" == "false" && "$func_name" =~ ^_ ]]; then
                    continue
                fi
                echo "- [\`${func_name}\`](#${func_name})"
            fi
        done < <(extract_functions "$file")

        echo ""
        echo "---"
        echo ""
        echo "## 函数详情"
        echo ""

        # 生成函数文档
        local current_func=""
        local current_doc=""

        while IFS= read -r line; do
            if [[ "$line" =~ ^FUNC: ]]; then
                # 输出上一个函数
                if [[ -n "$current_func" ]]; then
                    output_function_markdown "$current_func" "$current_doc"
                fi
                current_func="${line#FUNC:}"
                current_doc=""
            elif [[ "$line" =~ ^DOC: ]]; then
                current_doc="${line#DOC:}"
            fi
        done < <(extract_functions "$file")

        # 输出最后一个函数
        if [[ -n "$current_func" ]]; then
            output_function_markdown "$current_func" "$current_doc"
        fi

    } > "$output_file"
}

# 输出单个函数的 Markdown 文档
output_function_markdown() {
    local func_name="$1"
    local doc="$2"

    # 跳过私有函数
    if [[ "$INCLUDE_PRIVATE" == "false" && "$func_name" =~ ^_ ]]; then
        return
    fi

    echo "### \`${func_name}\`"
    echo ""

    if [[ -n "$doc" ]]; then
        # 简单解析文档
        local in_params=false
        local has_params=false

        while IFS= read -r line; do
            if [[ "$line" =~ ^@param ]]; then
                if [[ "$has_params" == false ]]; then
                    echo "**参数:**"
                    echo ""
                    has_params=true
                fi
                local param_info="${line#@param }"
                echo "- \`${param_info}\`"
            elif [[ "$line" =~ ^@return ]]; then
                echo ""
                echo "**返回值:** ${line#@return }"
            elif [[ "$line" =~ ^@example ]]; then
                echo ""
                echo "**示例:**"
                echo ""
                echo '```bash'
            elif [[ -n "$line" ]]; then
                echo "$line"
            fi
        done <<< "$doc"

        # 检查是否有未关闭的代码块
        if [[ "$doc" =~ @example ]]; then
            echo '```'
        fi
    else
        echo "*无文档*"
    fi

    echo ""
    echo "---"
    echo ""
}

# 生成 HTML 文档
generate_html() {
    local file="$1"
    local output_file="$2"
    local filename
    filename=$(basename "$file")

    {
        cat << 'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>API 文档</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            line-height: 1.6;
            color: #333;
        }
        h1 { border-bottom: 2px solid #667eea; padding-bottom: 10px; }
        h2 { color: #667eea; margin-top: 30px; }
        h3 { background: #f5f5f5; padding: 10px; border-left: 4px solid #667eea; }
        code {
            background: #f5f5f5;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Monaco', 'Menlo', monospace;
        }
        pre {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
        }
        pre code { background: transparent; color: inherit; }
        .toc { background: #f9f9f9; padding: 20px; border-radius: 5px; }
        .toc ul { list-style: none; padding-left: 20px; }
        .toc a { text-decoration: none; color: #667eea; }
        .toc a:hover { text-decoration: underline; }
        .param { margin: 5px 0; padding: 5px 10px; background: #f9f9f9; }
        .return { color: #28a745; }
        hr { border: none; border-top: 1px solid #eee; margin: 30px 0; }
    </style>
</head>
<body>
EOF
        echo "<h1>${filename%.sh} API 文档</h1>"
        echo "<p><em>自动生成于 $(date '+%Y-%m-%d %H:%M:%S')</em></p>"

        # 提取脚本头部
        local header
        header=$(extract_script_header "$file")
        if [[ -n "$header" ]]; then
            echo "<h2>概述</h2>"
            echo "<p>$header</p>"
        fi

        echo "<h2>函数列表</h2>"
        echo "<div class=\"toc\"><ul>"

        while IFS= read -r line; do
            if [[ "$line" =~ ^FUNC: ]]; then
                local func_name="${line#FUNC:}"
                if [[ "$INCLUDE_PRIVATE" == "false" && "$func_name" =~ ^_ ]]; then
                    continue
                fi
                echo "<li><a href=\"#${func_name}\"><code>${func_name}</code></a></li>"
            fi
        done < <(extract_functions "$file")

        echo "</ul></div>"
        echo "<hr>"
        echo "<h2>函数详情</h2>"

        local current_func=""
        local current_doc=""

        while IFS= read -r line; do
            if [[ "$line" =~ ^FUNC: ]]; then
                if [[ -n "$current_func" ]]; then
                    output_function_html "$current_func" "$current_doc"
                fi
                current_func="${line#FUNC:}"
                current_doc=""
            elif [[ "$line" =~ ^DOC: ]]; then
                current_doc="${line#DOC:}"
            fi
        done < <(extract_functions "$file")

        if [[ -n "$current_func" ]]; then
            output_function_html "$current_func" "$current_doc"
        fi

        echo "</body></html>"
    } > "$output_file"
}

# 输出单个函数的 HTML 文档
output_function_html() {
    local func_name="$1"
    local doc="$2"

    if [[ "$INCLUDE_PRIVATE" == "false" && "$func_name" =~ ^_ ]]; then
        return
    fi

    echo "<h3 id=\"${func_name}\"><code>${func_name}</code></h3>"

    if [[ -n "$doc" ]]; then
        echo "<div class=\"doc\">"

        while IFS= read -r line; do
            if [[ "$line" =~ ^@param ]]; then
                echo "<div class=\"param\"><strong>参数:</strong> <code>${line#@param }</code></div>"
            elif [[ "$line" =~ ^@return ]]; then
                echo "<p class=\"return\"><strong>返回值:</strong> ${line#@return }</p>"
            elif [[ "$line" =~ ^@example ]]; then
                echo "<p><strong>示例:</strong></p><pre><code>"
            elif [[ -n "$line" ]]; then
                echo "<p>$line</p>"
            fi
        done <<< "$doc"

        if [[ "$doc" =~ @example ]]; then
            echo "</code></pre>"
        fi

        echo "</div>"
    else
        echo "<p><em>无文档</em></p>"
    fi

    echo "<hr>"
}

# =============================================================================
# 生成索引
# =============================================================================

generate_index() {
    local index_file="$OUTPUT_DIR/README.md"

    {
        echo "# CI/CD Solution API 文档"
        echo ""
        echo "> 自动生成于 $(date '+%Y-%m-%d %H:%M:%S')"
        echo ""
        echo "## 模块列表"
        echo ""

        echo "### 核心库 (lib/core/)"
        echo ""
        for doc in "$OUTPUT_DIR"/lib-core-*.md; do
            [[ -f "$doc" ]] || continue
            local name
            name=$(basename "$doc" .md)
            echo "- [${name}](./${name}.md)"
        done
        echo ""

        echo "### 工具库 (lib/utils/)"
        echo ""
        for doc in "$OUTPUT_DIR"/lib-utils-*.md; do
            [[ -f "$doc" ]] || continue
            local name
            name=$(basename "$doc" .md)
            echo "- [${name}](./${name}.md)"
        done
        echo ""

        echo "### 脚本 (scripts/)"
        echo ""
        for doc in "$OUTPUT_DIR"/scripts-*.md; do
            [[ -f "$doc" ]] || continue
            local name
            name=$(basename "$doc" .md)
            echo "- [${name}](./${name}.md)"
        done
        echo ""

        echo "---"
        echo ""
        echo "## 快速开始"
        echo ""
        echo '```bash'
        echo "# 查看帮助"
        echo "./scripts/aicd.sh --help"
        echo ""
        echo "# 初始化项目"
        echo "./scripts/aicd.sh init"
        echo ""
        echo "# 验证配置"
        echo "./scripts/aicd.sh validate"
        echo '```'

    } > "$index_file"

    print_success "索引文件已生成: $index_file"
}

# =============================================================================
# 主函数
# =============================================================================

show_help() {
    cat << EOF
用法: $0 [选项]

API 文档生成工具

选项:
  -f, --format FORMAT   输出格式 (markdown, html) [默认: markdown]
  -o, --output DIR      输出目录 [默认: docs/api]
  -p, --private         包含私有函数（以 _ 开头）
  -h, --help            显示此帮助信息

示例:
  $0                           # 生成 Markdown 文档
  $0 --format html             # 生成 HTML 文档
  $0 --output /path/to/docs    # 指定输出目录

EOF
}

main() {
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -p|--private)
                INCLUDE_PRIVATE="true"
                shift
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

    print_header "API 文档生成"

    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"

    local total_files=0
    local processed=0

    # 统计文件数量
    total_files=$(find "$PROJECT_ROOT/lib" "$PROJECT_ROOT/scripts" -name "*.sh" -type f 2>/dev/null | wc -l)

    print_info "发现 $total_files 个脚本文件"
    echo ""

    # 处理 lib/core 目录
    for file in "$PROJECT_ROOT"/lib/core/*.sh; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file" .sh)
        local output_file="$OUTPUT_DIR/lib-core-${filename}"

        ((processed++))
        echo -en "\r处理中: [$processed/$total_files] $filename"

        case "$OUTPUT_FORMAT" in
            html)
                generate_html "$file" "${output_file}.html"
                ;;
            *)
                generate_markdown "$file" "${output_file}.md"
                ;;
        esac
    done

    # 处理 lib/utils 目录
    for file in "$PROJECT_ROOT"/lib/utils/*.sh; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file" .sh)
        local output_file="$OUTPUT_DIR/lib-utils-${filename}"

        ((processed++))
        echo -en "\r处理中: [$processed/$total_files] $filename"

        case "$OUTPUT_FORMAT" in
            html)
                generate_html "$file" "${output_file}.html"
                ;;
            *)
                generate_markdown "$file" "${output_file}.md"
                ;;
        esac
    done

    # 处理 scripts 目录
    for file in "$PROJECT_ROOT"/scripts/*.sh; do
        [[ -f "$file" ]] || continue
        local filename
        filename=$(basename "$file" .sh)
        local output_file="$OUTPUT_DIR/scripts-${filename}"

        ((processed++))
        echo -en "\r处理中: [$processed/$total_files] $filename"

        case "$OUTPUT_FORMAT" in
            html)
                generate_html "$file" "${output_file}.html"
                ;;
            *)
                generate_markdown "$file" "${output_file}.md"
                ;;
        esac
    done

    echo ""
    echo ""

    # 生成索引
    if [[ "$OUTPUT_FORMAT" == "markdown" ]]; then
        generate_index
    fi

    print_success "文档生成完成！"
    print_info "输出目录: $OUTPUT_DIR"
    print_info "文件格式: $OUTPUT_FORMAT"
}

main "$@"
