#!/bin/bash

# 文档自动化生成脚本
# 根据配置文件和脚本自动生成相关文档

set -euo pipefail

# 加载统一颜色库
GEN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$GEN_SCRIPT_DIR/../lib/utils/colors.sh"

# 日志函数（使用统一颜色库）
gen_log_debug() {
    if [ "${GEN_LOG_LEVEL:-INFO}" = "DEBUG" ]; then
        echo -e "${COLOR_BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [GENERATE DEBUG]${COLOR_NC} $1" >&2
    fi
}

gen_log_info() {
    echo -e "${COLOR_GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [GENERATE INFO]${COLOR_NC} $1" >&2
}

gen_log_warn() {
    echo -e "${COLOR_YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [GENERATE WARN]${COLOR_NC} $1" >&2
}

gen_log_error() {
    echo -e "${COLOR_RED}[$(date +'%Y-%m-%d %H:%M:%S')] [GENERATE ERROR]${COLOR_NC} $1" >&2
}

# 默认参数
GEN_CONFIG_FILE="/root/idear/cicd-solution/config/central-config.yaml"
GEN_SCRIPTS_DIR="/root/idear/cicd-solution/shared-scripts"
GEN_TEMPLATES_DIR="/root/idear/cicd-solution/templates"
GEN_OUTPUT_DIR="/root/idear/cicd-solution/docs"
GEN_FORCE=false

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

文档自动化生成脚本

选项:
  -c, --config FILE        配置文件路径 [默认: $GEN_CONFIG_FILE]
  -s, --scripts DIR        脚本目录路径 [默认: $GEN_SCRIPTS_DIR]
  -t, --templates DIR      模板目录路径 [默认: $GEN_TEMPLATES_DIR]
  -o, --output DIR         输出目录路径 [默认: $GEN_OUTPUT_DIR]
  -f, --force              强制重新生成所有文档
  -h, --help               显示此帮助信息

示例:
  $0 -c ./config.yaml -s ./scripts -o ./docs
  $0 --force

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            GEN_CONFIG_FILE="$2"
            shift 2
            ;;
        -s|--scripts)
            GEN_SCRIPTS_DIR="$2"
            shift 2
            ;;
        -t|--templates)
            GEN_TEMPLATES_DIR="$2"
            shift 2
            ;;
        -o|--output)
            GEN_OUTPUT_DIR="$2"
            shift 2
            ;;
        -f|--force)
            GEN_FORCE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            gen_log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必要命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        gen_log_error "缺少必要命令: $1"
        exit 1
    fi
}

# 生成配置文档
generate_config_documentation() {
    local config_file="$1"
    local output_file="$2"
    
    gen_log_info "生成配置文档: $output_file"
    
    # 检查配置文件是否存在
    if [ ! -f "$config_file" ]; then
        gen_log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 生成配置文档
    cat > "$output_file" << EOF
# CI/CD 配置说明

此文档描述了CI/CD流程中使用的配置项。

## 配置文件路径

- 全局配置文件: $config_file

## 配置项说明

EOF
    
    # 解析YAML配置文件并生成文档
    if command -v yq &> /dev/null; then
        # 提取主要配置部分
        local sections=("global" "build" "test" "deploy" "rollback" "security" "monitoring" "cache" "notification")
        
        for section in "${sections[@]}"; do
            if yq eval ".$section" "$config_file" &> /dev/null; then
                echo "## $section" >> "$output_file"
                echo "" >> "$output_file"
                
                # 提取该部分的配置项
                yq eval ".$section" "$config_file" | sed 's/^/    /' >> "$output_file"
                echo "" >> "$output_file"
            fi
        done
    else
        gen_log_warn "缺少yq命令，无法解析YAML配置文件详情"
        echo "无法解析配置文件详情，请安装yq工具。" >> "$output_file"
    fi
    
    gen_log_info "配置文档生成完成: $output_file"
}

# 生成脚本文档
generate_script_documentation() {
    local scripts_dir="$1"
    local output_file="$2"
    
    gen_log_info "生成脚本文档: $output_file"
    
    # 检查脚本目录是否存在
    if [ ! -d "$scripts_dir" ]; then
        gen_log_error "脚本目录不存在: $scripts_dir"
        return 1
    fi
    
    # 生成脚本文档
    cat > "$output_file" << EOF
# CI/CD 共享脚本说明

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
            script_desc=$(head -n 1 "$script" | sed 's/^# *//')
            
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
    
    gen_log_info "脚本文档生成完成: $output_file"
}

# 生成模板文档
generate_template_documentation() {
    local template_dir="$1"
    local output_file="$2"
    
    gen_log_info "生成模板文档: $output_file"
    
    # 检查模板目录是否存在
    if [ ! -d "$template_dir" ]; then
        gen_log_warn "模板目录不存在: $template_dir"
        return 1
    fi
    
    # 生成模板文档
    cat > "$output_file" << EOF
# CI/CD 模板说明

此文档描述了CI/CD流程中使用的模板文件。

## 模板目录

- 模板目录路径: $template_dir

## 模板结构

EOF
    
    # 遍历模板目录，生成文档
    find "$template_dir" -type f \( -name "*.yml" -o -name "*.yaml" \) | while read -r template; do
        local template_path=${template#$template_dir/}
        echo "- $template_path" >> "$output_file"
    done
    
    echo "" >> "$output_file"
    
    # 添加模板使用说明
    echo "## 模板使用说明" >> "$output_file"
    echo "" >> "$output_file"
    echo "模板文件可用于快速创建CI/CD流程，支持以下平台：" >> "$output_file"
    echo "" >> "$output_file"
    echo "1. GitHub Actions" >> "$output_file"
    echo "2. GitLab CI" >> "$output_file"
    echo "3. Jenkins" >> "$output_file"
    echo "4. Kubernetes" >> "$output_file"
    echo "" >> "$output_file"
    
    gen_log_info "模板文档生成完成: $output_file"
}

# 生成使用手册
generate_user_manual() {
    local output_file="$1"
    
    gen_log_info "生成使用手册: $output_file"
    
    # 生成使用手册
    cat > "$output_file" << 'EOF'
# CI/CD 使用手册

## 目录

1. [快速开始](#快速开始)
2. [配置管理](#配置管理)
3. [脚本使用](#脚本使用)
4. [模板使用](#模板使用)
5. [常见问题](#常见问题)

## 快速开始

### 环境准备

1. 安装必要工具：
   - Docker
   - kubectl (如果使用Kubernetes)
   - git

2. 克隆代码仓库：
   ```bash
   git clone <repository-url>
   cd <project-directory>
   ```

3. 配置环境变量：
   ```bash
   export ENV=production
   ```

### 运行CI/CD流程

1. 构建应用：
   ```bash
   ./scripts/build.sh
   ```

2. 运行测试：
   ```bash
   ./scripts/test.sh
   ```

3. 部署应用：
   ```bash
   ./scripts/deploy.sh
   ```

## 配置管理

### 配置文件

配置文件位于 `config/` 目录下，主要包含：

- `central-config.yaml`: 中心化配置文件
- `environment/`: 环境特定配置

### 配置验证

在运行CI/CD流程前，建议验证配置文件：
```bash
./scripts/validate-config.sh
```

## 脚本使用

### 共享脚本

共享脚本位于 `shared-scripts/` 目录下，可在不同项目中复用。

### 脚本引用

在CI/CD流程中引用脚本：
```bash
source ./lib/core-loader.sh
set_log_module "DocGenerator"
```

## 模板使用

### 模板目录

模板文件位于 `templates/` 目录下，按平台分类：

- `github/`: GitHub Actions模板
- `gitlab/`: GitLab CI模板
- `jenkins/`: Jenkinsfile模板
- `kubernetes/`: Kubernetes部署模板

### 使用模板

复制模板到项目根目录并根据需要修改：
```bash
cp templates/github/ci.yml .github/workflows/
```

## 常见问题

### 构建失败

1. 检查依赖是否正确安装
2. 查看构建日志获取详细错误信息
3. 确认配置文件是否正确

### 部署失败

1. 检查Kubernetes集群连接
2. 验证镜像是否存在
3. 查看部署日志获取详细错误信息

### 测试失败

1. 检查测试环境配置
2. 确认测试数据是否正确
3. 查看测试日志获取详细错误信息
EOF
    
    gen_log_info "使用手册生成完成: $output_file"
}

# 主生成流程
main() {
    gen_log_info "开始执行文档自动化生成流程"
    gen_log_info "配置文件: $GEN_CONFIG_FILE"
    gen_log_info "脚本目录: $GEN_SCRIPTS_DIR"
    gen_log_info "模板目录: $GEN_TEMPLATES_DIR"
    gen_log_info "输出目录: $GEN_OUTPUT_DIR"
    gen_log_info "强制生成: $GEN_FORCE"
    
    # 创建输出目录
    mkdir -p "$GEN_OUTPUT_DIR"
    
    # 生成各类文档
    generate_config_documentation "$GEN_CONFIG_FILE" "$GEN_OUTPUT_DIR/config-documentation.md"
    generate_script_documentation "$GEN_SCRIPTS_DIR" "$GEN_OUTPUT_DIR/script-documentation.md"
    generate_template_documentation "$GEN_TEMPLATES_DIR" "$GEN_OUTPUT_DIR/template-documentation.md"
    generate_user_manual "$GEN_OUTPUT_DIR/USER_MANUAL.md"
    
    gen_log_info "文档自动化生成流程完成"
}

# 执行主函数
main "$@"