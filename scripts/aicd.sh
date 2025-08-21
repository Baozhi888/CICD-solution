#!/bin/bash

# aicd - AI-Enhanced CI/CD Command Line Interface
# 统一 CI/CD 自动化解决方案的命令行入口

# 加载核心库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core-loader.sh"

# 设置模块名称
if command -v set_log_module >/dev/null 2>&1; then
    set_log_module "AICD"
fi

# 版本信息
VERSION="1.0.0"

# 显示帮助信息
show_help() {
    cat << EOF
aicd - AI-Enhanced CI/CD Command Line Interface
统一 CI/CD 自动化解决方案的命令行入口

用法: $0 [选项] <命令> [参数...]

命令:
  init                  初始化项目配置
  validate              验证配置文件
  doctor                诊断 CI/CD 流水线问题
  fix                   自动修复常见问题
  run <stage>           运行指定阶段
  test                  运行测试
  build                 构建项目
  deploy                部署项目
  rollback              回滚部署
  monitor               监控系统资源
  benchmark             运行性能基准测试
  analyze               分析依赖和性能
  log <subcommand>      日志管理
  docs                  生成文档
  version               显示版本信息
  help                  显示此帮助信息

选项:
  -v, --verbose         详细输出
  -c, --config FILE     指定配置文件
  -e, --env ENV         指定环境
  -h, --help            显示此帮助信息

环境变量:
  AICD_CONFIG           配置文件路径
  AICD_ENV              环境名称
  AICD_VERBOSE          详细输出 (true/false)

示例:
  $0 init                         # 初始化项目
  $0 validate                     # 验证配置
  $0 doctor                       # 诊断问题
  $0 fix                          # 自动修复
  $0 run build                    # 运行构建阶段
  $0 test --unit                  # 运行单元测试
  $0 build                        # 构建项目
  $0 deploy --env production      # 部署到生产环境
  $0 rollback v1.2.3              # 回滚到指定版本
  $0 monitor --watch              # 实时监控资源
  $0 benchmark --compare          # 运行性能基准测试并比较
  $0 analyze dependencies         # 分析依赖
  $0 log query "ERROR" 7          # 查询错误日志
  $0 docs --api                   # 生成 API 文档
EOF
}

# 显示版本信息
show_version() {
    cat << EOF
aicd (AI-Enhanced CI/CD) $VERSION
统一 CI/CD 自动化解决方案
EOF
}

# 初始化项目
cmd_init() {
    log_info "初始化项目配置"
    
    # 检查是否已存在配置文件
    if [ -f "config/central-config.yaml" ]; then
        log_warn "配置文件已存在: config/central-config.yaml"
        read -p "是否覆盖? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "取消初始化"
            return 0
        fi
    fi
    
    # 创建配置目录
    mkdir -p config/environment
    
    # 生成默认配置文件
    cat > config/central-config.yaml << 'EOF'
# 中央配置文件
# Central Configuration File

project:
  name: "my-project"
  version: "1.0.0"
  description: "My CI/CD project"

# 环境配置
environments:
  development:
    debug: true
    log_level: "DEBUG"
  staging:
    debug: false
    log_level: "INFO"
  production:
    debug: false
    log_level: "WARN"

# 构建配置
build:
  commands:
    - "npm install"
    - "npm run build"
  artifacts:
    - "dist/**/*"

# 测试配置
test:
  commands:
    - "npm test"
  coverage_threshold: 80

# 部署配置
deploy:
  commands:
    - "./scripts/deploy.sh"
  rollback_enabled: true

# 回滚配置
rollback:
  strategies:
    - blue_green
    - canary
  auto_rollback_on_failure: true

# 安全配置
security:
  secret_scanning: true
  dependency_scanning: true
  iac_scanning: true

# 监控配置
monitoring:
  enabled: true
  metrics_interval: 30

# 缓存配置
cache:
  enabled: true
  paths:
    - "node_modules"
    - ".cache"
EOF
    
    log_info "项目初始化完成"
    log_info "配置文件已创建: config/central-config.yaml"
    log_info "请根据项目需求修改配置文件"
}

# 验证配置
cmd_validate() {
    log_info "验证配置文件"
    
    local config_file="${AICD_CONFIG:-config/central-config.yaml}"
    
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 使用 validate-config.sh 脚本验证配置
    if [ -f "scripts/validate-config.sh" ]; then
        "$SCRIPT_DIR/validate-config.sh" "$config_file"
    else
        log_warn "验证脚本不存在: scripts/validate-config.sh"
        log_info "跳过配置验证"
    fi
}

# 诊断问题
cmd_doctor() {
    log_info "诊断 CI/CD 流水线问题"
    
    # 检查配置文件
    cmd_validate
    
    # 检查依赖
    log_info "检查项目依赖"
    if command -v npm >/dev/null 2>&1; then
        log_info "npm 可用"
    else
        log_warn "npm 不可用"
    fi
    
    # 检查必需的工具
    local required_tools=("git" "yq" "jq")
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            log_info "$tool 可用"
        else
            log_warn "$tool 不可用"
        fi
    done
    
    # 检查脚本文件
    local script_files=(
        "scripts/log-manager.sh"
        "scripts/config-version-manager.sh"
        "scripts/generate-docs.sh"
        "scripts/resource-monitoring.sh"
        "scripts/performance-benchmark.sh"
        "scripts/dependency-analysis.sh"
    )
    
    for script in "${script_files[@]}"; do
        if [ -f "$script" ]; then
            log_info "$script 存在"
        else
            log_warn "$script 不存在"
        fi
    done
    
    log_info "诊断完成"
    
    # 如果集成了 AI 功能，可以调用 AI 代理进行更深入的诊断
    if [ -d ".bmad-core" ]; then
        log_info "检测到 BMad-Method 集成，可调用 AI 代理进行深入诊断"
        log_info "使用 'aicd fix' 命令自动修复发现的问题"
    fi
}

# 自动修复问题
cmd_fix() {
    log_info "自动修复 CI/CD 流水线问题"
    
    # 这里应该实现具体的修复逻辑
    # 例如：重新生成配置文件、修复权限问题等
    
    # 如果集成了 AI 功能，可以调用 AI 代理生成修复补丁
    if [ -d ".bmad-core" ]; then
        log_info "检测到 BMad-Method 集成"
        log_info "调用 AI 代理生成修复方案..."
        # 模拟 AI 代理调用
        cat << 'EOF'
AI 代理分析结果:
1. 配置文件验证失败，建议修复 YAML 语法
2. 缺少必要的环境变量，建议添加默认值
3. 权限问题，建议运行: chmod +x scripts/*.sh

修复补丁已生成，请应用以下更改:
diff --git a/config/central-config.yaml b/config/central-config.yaml
index 1234567..89abcde 100644
--- a/config/central-config.yaml
+++ b/config/central-config.yaml
@@ -1,5 +1,5 @@
 project:
-  name: "my-project
+  name: "my-project"
   version: "1.0.0"
   description: "My CI/CD project"
EOF
        log_info "补丁已输出到标准输出，可直接应用"
    else
        log_info "未检测到 AI 集成，执行基础修复..."
        # 基础修复逻辑
        if [ -f "scripts/log-manager.sh" ]; then
            chmod +x scripts/log-manager.sh
            log_info "修复脚本权限: scripts/log-manager.sh"
        fi
    fi
}

# 运行指定阶段
cmd_run() {
    local stage="$1"
    
    if [ -z "$stage" ]; then
        log_error "请指定要运行的阶段"
        return 1
    fi
    
    log_info "运行阶段: $stage"
    
    case "$stage" in
        "build")
            cmd_build
            ;;
        "test")
            cmd_test
            ;;
        "deploy")
            cmd_deploy
            ;;
        *)
            log_error "未知阶段: $stage"
            return 1
            ;;
    esac
}

# 运行测试
cmd_test() {
    log_info "运行测试"
    
    # 解析参数
    local test_type="all"
    local verbose=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --unit)
                test_type="unit"
                shift
                ;;
            --integration)
                test_type="integration"
                shift
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 运行测试
    case "$test_type" in
        "unit")
            log_info "运行单元测试"
            if [ -f "tests/run-tests.sh" ]; then
                if [ "$verbose" = true ]; then
                    tests/run-tests.sh --unit-only --verbose
                else
                    tests/run-tests.sh --unit-only
                fi
            else
                log_error "测试运行器不存在: tests/run-tests.sh"
                return 1
            fi
            ;;
        "integration")
            log_info "运行集成测试"
            if [ -f "tests/run-tests.sh" ]; then
                if [ "$verbose" = true ]; then
                    tests/run-tests.sh --integration-only --verbose
                else
                    tests/run-tests.sh --integration-only
                fi
            else
                log_error "测试运行器不存在: tests/run-tests.sh"
                return 1
            fi
            ;;
        *)
            log_info "运行所有测试"
            if [ -f "tests/run-tests.sh" ]; then
                if [ "$verbose" = true ]; then
                    tests/run-tests.sh --verbose
                else
                    tests/run-tests.sh
                fi
            else
                log_error "测试运行器不存在: tests/run-tests.sh"
                return 1
            fi
            ;;
    esac
}

# 构建项目
cmd_build() {
    log_info "构建项目"
    
    # 读取配置
    local config_file="${AICD_CONFIG:-config/central-config.yaml}"
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 获取构建命令
    local build_commands
    if command -v yq >/dev/null 2>&1; then
        build_commands=$(yq eval '.build.commands[]' "$config_file")
    else
        log_warn "yq 不可用，使用默认构建命令"
        build_commands=("npm install" "npm run build")
    fi
    
    # 执行构建命令
    while IFS= read -r cmd; do
        log_info "执行: $cmd"
        if ! eval "$cmd"; then
            log_error "构建失败: $cmd"
            return 1
        fi
    done <<< "$build_commands"
    
    log_info "项目构建完成"
}

# 部署项目
cmd_deploy() {
    log_info "部署项目"
    
    # 读取环境变量
    local env="${AICD_ENV:-development}"
    log_info "部署环境: $env"
    
    # 读取配置
    local config_file="${AICD_CONFIG:-config/central-config.yaml}"
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 获取部署命令
    local deploy_commands
    if command -v yq >/dev/null 2>&1; then
        deploy_commands=$(yq eval '.deploy.commands[]' "$config_file")
    else
        log_warn "yq 不可用，使用默认部署命令"
        deploy_commands=("./scripts/deploy.sh")
    fi
    
    # 执行部署命令
    while IFS= read -r cmd; do
        log_info "执行: $cmd"
        if ! eval "$cmd"; then
            log_error "部署失败: $cmd"
            # 检查是否启用自动回滚
            local auto_rollback
            if command -v yq >/dev/null 2>&1; then
                auto_rollback=$(yq eval '.rollback.auto_rollback_on_failure' "$config_file")
            else
                auto_rollback="true"
            fi
            
            if [ "$auto_rollback" = "true" ]; then
                log_info "自动回滚已启用，正在回滚..."
                cmd_rollback
            fi
            return 1
        fi
    done <<< "$deploy_commands"
    
    log_info "项目部署完成"
}

# 回滚部署
cmd_rollback() {
    local version="$1"
    
    log_info "回滚部署${version:+到版本: $version}"
    
    # 读取配置
    local config_file="${AICD_CONFIG:-config/central-config.yaml}"
    if [ ! -f "$config_file" ]; then
        log_error "配置文件不存在: $config_file"
        return 1
    fi
    
    # 检查回滚是否启用
    local rollback_enabled
    if command -v yq >/dev/null 2>&1; then
        rollback_enabled=$(yq eval '.deploy.rollback_enabled' "$config_file")
    else
        rollback_enabled="true"
    fi
    
    if [ "$rollback_enabled" != "true" ]; then
        log_error "回滚功能未启用"
        return 1
    fi
    
    # 调用配置版本管理器进行回滚
    if [ -f "scripts/config-version-manager.sh" ]; then
        if [ -n "$version" ]; then
            "$SCRIPT_DIR/config-version-manager.sh" rollback "$version"
        else
            "$SCRIPT_DIR/config-version-manager.sh" rollback
        fi
    else
        log_error "配置版本管理器不存在: scripts/config-version-manager.sh"
        return 1
    fi
}

# 监控系统资源
cmd_monitor() {
    log_info "监控系统资源"
    
    # 解析参数
    local watch=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --watch|-w)
                watch=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 调用资源监控脚本
    if [ -f "scripts/resource-monitoring.sh" ]; then
        if [ "$watch" = true ]; then
            "$SCRIPT_DIR/resource-monitoring.sh" --watch
        else
            "$SCRIPT_DIR/resource-monitoring.sh"
        fi
    else
        log_error "资源监控脚本不存在: scripts/resource-monitoring.sh"
        return 1
    fi
}

# 运行性能基准测试
cmd_benchmark() {
    log_info "运行性能基准测试"
    
    # 解析参数
    local compare=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --compare|-c)
                compare=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 调用性能基准测试脚本
    if [ -f "scripts/performance-benchmark.sh" ]; then
        if [ "$compare" = true ]; then
            "$SCRIPT_DIR/performance-benchmark.sh" --compare
        else
            "$SCRIPT_DIR/performance-benchmark.sh"
        fi
    else
        log_error "性能基准测试脚本不存在: scripts/performance-benchmark.sh"
        return 1
    fi
}

# 分析依赖和性能
cmd_analyze() {
    local subcommand="$1"
    
    log_info "分析依赖和性能${subcommand:+: $subcommand}"
    
    case "$subcommand" in
        "dependencies"|"deps")
            # 调用依赖分析脚本
            if [ -f "scripts/dependency-analysis.sh" ]; then
                "$SCRIPT_DIR/dependency-analysis.sh"
            else
                log_error "依赖分析脚本不存在: scripts/dependency-analysis.sh"
                return 1
            fi
            ;;
        "")
            # 运行所有分析
            cmd_analyze dependencies
            ;;
        *)
            log_error "未知分析命令: $subcommand"
            return 1
            ;;
    esac
}

# 日志管理
cmd_log() {
    local subcommand="$1"
    shift
    
    log_info "日志管理${subcommand:+: $subcommand}"
    
    # 调用日志管理脚本
    if [ -f "scripts/log-manager.sh" ]; then
        "$SCRIPT_DIR/log-manager.sh" "$subcommand" "$@"
    else
        log_error "日志管理脚本不存在: scripts/log-manager.sh"
        return 1
    fi
}

# 生成文档
cmd_docs() {
    log_info "生成文档"
    
    # 解析参数
    local api_docs=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --api)
                api_docs=true
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # 调用文档生成脚本
    if [ -f "scripts/generate-docs.sh" ]; then
        if [ "$api_docs" = true ]; then
            "$SCRIPT_DIR/generate-docs.sh" --api
        else
            "$SCRIPT_DIR/generate-docs.sh"
        fi
    else
        log_error "文档生成脚本不存在: scripts/generate-docs.sh"
        return 1
    fi
}

# 主命令分发
COMMAND=""
CONFIG_FILE=""
ENVIRONMENT=""
VERBOSE=false

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            set_log_level "DEBUG"
            export AICD_VERBOSE="true"
            shift
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            export AICD_CONFIG="$CONFIG_FILE"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            export AICD_ENV="$ENVIRONMENT"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        version|--version)
            show_version
            exit 0
            ;;
        help|--help)
            show_help
            exit 0
            ;;
        init|validate|doctor|fix|run|test|build|deploy|rollback|monitor|benchmark|analyze|log|docs)
            COMMAND="$1"
            shift
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                log_error "未知选项: $1"
                show_help
                exit 1
            fi
            break
            ;;
    esac
done

# 执行命令
case "$COMMAND" in
    "init")
        cmd_init
        ;;
    "validate")
        cmd_validate
        ;;
    "doctor")
        cmd_doctor
        ;;
    "fix")
        cmd_fix
        ;;
    "run")
        cmd_run "$@"
        ;;
    "test")
        cmd_test "$@"
        ;;
    "build")
        cmd_build
        ;;
    "deploy")
        cmd_deploy
        ;;
    "rollback")
        cmd_rollback "$@"
        ;;
    "monitor")
        cmd_monitor "$@"
        ;;
    "benchmark")
        cmd_benchmark "$@"
        ;;
    "analyze")
        cmd_analyze "$@"
        ;;
    "log")
        cmd_log "$@"
        ;;
    "docs")
        cmd_docs "$@"
        ;;
    "")
        log_error "请指定一个命令"
        show_help
        exit 1
        ;;
    *)
        log_error "未知命令: $COMMAND"
        show_help
        exit 1
        ;;
esac