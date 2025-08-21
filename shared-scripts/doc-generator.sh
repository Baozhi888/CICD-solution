#!/bin/bash

# 文档生成器
# 根据配置文件和脚本自动生成文档

# 颜色定义
DOC_RED='\033[0;31m'
DOC_GREEN='\033[0;32m'
DOC_YELLOW='\033[1;33m'
DOC_BLUE='\033[0;34m'
DOC_NC='\033[0m' # No Color

# 日志函数
doc_log_debug() {
    if [ "${DOC_LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        echo -e "${DOC_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [DOC DEBUG]${DOC_NC} $1" >&2
    fi
}

doc_log_info() {
    echo -e "${DOC_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [DOC INFO]${DOC_NC} $1" >&2
}

doc_log_warn() {
    echo -e "${DOC_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [DOC WARN]${DOC_NC} $1" >&2
}

doc_log_error() {
    echo -e "${DOC_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [DOC ERROR]${DOC_NC} $1" >&2
}

# 默认参数
DOC_CONFIG_FILE="/root/idear/cicd-solution/config/central-config.yaml"
DOC_SCRIPTS_DIR="/root/idear/cicd-solution/shared-scripts"
DOC_OUTPUT_DIR="./docs"
DOC_TEMPLATE_DIR="/root/idear/cicd-solution/templates"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

文档生成器

选项:
  -c, --config FILE        配置文件路径 [默认: $DOC_CONFIG_FILE]
  -s, --scripts DIR        脚本目录路径 [默认: $DOC_SCRIPTS_DIR]
  -o, --output DIR         输出目录路径 [默认: $DOC_OUTPUT_DIR]
  -t, --template DIR       模板目录路径 [默认: $DOC_TEMPLATE_DIR]
  -h, --help               显示此帮助信息

示例:
  $0 -c ./config.yaml -s ./scripts -o ./generated-docs
  $0 --config /path/to/config.yml --output /path/to/docs

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            DOC_CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--scripts)
            DOC_SCRIPTS_DIR="$2"
            shift 2
            ;;
        -o|--output)
            DOC_OUTPUT_DIR="$2"
            shift 2
            ;;
        -t|--template)
            DOC_TEMPLATE_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            doc_log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必要命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        doc_log_error "缺少必要命令: $1"
        exit 1
    fi
}

# 生成配置文档
generate_config_docs() {
    local config_file="$1"
    local output_file="$2"
    
    doc_log_info "生成配置文档: $output_file"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        doc_log_warn "配置文件不存在: $config_file"
        return 1
    fi
    
    # 生成配置文档
    cat > "$output_file" << EOF
# 配置说明

此文档描述了CI/CD流程中使用的配置项。

## 配置文件路径

- 全局配置文件: $config_file

## 配置项说明

EOF
    
    # 解析YAML配置文件并生成文档
    if command -v yq &> /dev/null; then
        # 提取配置项和注释
        yq eval 'to_entries | .[] | "### " + .key + "\n\n类型: " + (.value | type) + "\n\n默认值: " + (.value | tostring) + "\n"' "$config_file" >> "$output_file"
    else
        doc_log_warn "缺少yq命令，无法解析YAML配置文件详情"
        echo "无法解析配置文件详情，请安装yq工具。" >> "$output_file"
    fi
    
    doc_log_info "配置文档生成完成: $output_file"
}

# 生成脚本文档
generate_script_docs() {
    local scripts_dir="$1"
    local output_file="$2"
    
    doc_log_info "生成脚本文档: $output_file"
    
    # 检查脚本目录是否存在
    if [ ! -d "$scripts_dir" ]; then
        doc_log_error "脚本目录不存在: $scripts_dir"
        return 1
    fi
    
    # 生成脚本文档
    cat > "$output_file" << EOF
# 脚本说明

此文档描述了CI/CD流程中使用的共享脚本。

## 脚本目录

- 脚本目录路径: $scripts_dir

## 脚本列表

EOF
    
    # 遍历脚本目录，生成文档
    for script in "$scripts_dir"/*.sh; do
        if [ -f "$script" ]; then
            local script_name=$(basename "$script")
            local script_desc=""
            
            # 提取脚本描述（第一行注释）
            script_desc=$(head -n 20 "$script" | grep -E "^# " | head -n 1 | sed 's/^# //')
            
            echo "### $script_name" >> "$output_file"
            echo "" >> "$output_file"
            if [ -n "$script_desc" ]; then
                echo "描述: $script_desc" >> "$output_file"
            else
                echo "描述: 暂无描述" >> "$output_file"
            fi
            echo "" >> "$output_file"
            
            # 提取函数列表
            echo "#### 函数列表" >> "$output_file"
            echo "" >> "$output_file"
            
            # 提取函数名和注释
            local in_function=false
            local func_name=""
            local func_comment=""
            
            while IFS= read -r line; do
                # 匹配函数定义
                if [[ $line =~ ^[[:space:]]*([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*\{ ]]; then
                    func_name="${BASH_REMATCH[1]}"
                    echo "- \`$func_name\`" >> "$output_file"
                fi
            done < "$script"
            
            echo "" >> "$output_file"
        fi
    done
    
    doc_log_info "脚本文档生成完成: $output_file"
}

# 生成模板文档
generate_template_docs() {
    local template_dir="$1"
    local output_file="$2"
    
    doc_log_info "生成模板文档: $output_file"
    
    # 检查模板目录是否存在
    if [ ! -d "$template_dir" ]; then
        doc_log_warn "模板目录不存在: $template_dir"
        return 1
    fi
    
    # 生成模板文档
    cat > "$output_file" << EOF
# 模板说明

此文档描述了CI/CD流程中使用的模板文件。

## 模板目录

- 模板目录路径: $template_dir

## 模板结构

EOF
    
    # 遍历模板目录，生成文档
    find "$template_dir" -type f -name "*.yml" -o -name "*.yaml" | while read -r template; do
        local template_path=${template#$template_dir/}
        echo "- $template_path" >> "$output_file"
    done
    
    doc_log_info "模板文档生成完成: $output_file"
}

# 生成开发者指南
generate_developer_guide() {
    local output_file="$1"
    
    doc_log_info "生成开发者指南: $output_file"
    
    # 生成开发者指南
    cat > "$output_file" << 'EOF'
# CI/CD 开发者指南

## 目录

1. [概述](#概述)
2. [配置管理](#配置管理)
3. [脚本使用](#脚本使用)
4. [模板使用](#模板使用)
5. [最佳实践](#最佳实践)
6. [故障排除](#故障排除)

## 概述

本文档为开发者提供了CI/CD流程的使用指南，包括配置管理、脚本使用、模板使用等方面的内容。

## 配置管理

### 配置文件结构

配置文件采用YAML格式，包含以下主要部分：

- 全局配置
- 项目配置
- 环境配置

### 配置加载顺序

配置加载遵循以下优先级顺序：

1. 环境变量
2. 本地配置文件
3. 全局配置文件

### 配置验证

配置文件在使用前会进行验证，确保必需配置项的存在和有效性。

## 脚本使用

### 共享脚本库

共享脚本库包含以下类型的脚本：

- 日志记录
- 通用工具
- 参数验证
- 配置管理

### 脚本引用方式

在CI/CD流程中引用脚本的方式：

```bash
source /path/to/lib/core-loader.sh
set_log_module "DocGenerator"
```

## 模板使用

### 模板类型

支持的模板类型包括：

- GitHub Actions
- GitLab CI
- Jenkinsfile

### 模板定制

模板可通过配置文件进行定制，支持不同环境的配置覆盖。

## 最佳实践

### 配置管理最佳实践

1. 敏感信息使用环境变量或密钥管理
2. 配置文件版本控制
3. 配置项文档化

### 脚本编写最佳实践

1. 脚本职责单一
2. 提供清晰的使用说明
3. 错误处理和日志记录

### 模板使用最佳实践

1. 模板参数化
2. 模板版本管理
3. 模板测试

## 故障排除

### 常见问题

1. 配置文件加载失败
2. 脚本执行错误
3. 模板渲染问题

### 日志查看

通过查看相关日志文件进行问题诊断。
EOF
    
    doc_log_info "开发者指南生成完成: $output_file"
}

# 主生成流程
main() {
    doc_log_info "开始执行文档生成流程"
    
    # 检查必要命令
    check_command "yq"
    
    # 创建输出目录
    mkdir -p "$DOC_OUTPUT_DIR"
    
    # 生成各类文档
    generate_config_docs "$DOC_CONFIG_FILE" "$DOC_OUTPUT_DIR/config-docs.md"
    generate_script_docs "$DOC_SCRIPTS_DIR" "$DOC_OUTPUT_DIR/script-docs.md"
    generate_template_docs "$DOC_TEMPLATE_DIR" "$DOC_OUTPUT_DIR/template-docs.md"
    generate_developer_guide "$DOC_OUTPUT_DIR/DEVELOPER_GUIDE.md"
    
    doc_log_info "文档生成流程完成"
}

# 执行主函数
main "$@"