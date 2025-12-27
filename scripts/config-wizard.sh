#!/bin/bash

# =============================================================================
# config-wizard.sh - 交互式配置向导
# =============================================================================
# 通过交互式问答生成项目配置文件
#
# 用法:
#   ./scripts/config-wizard.sh              # 启动向导
#   ./scripts/config-wizard.sh --quick      # 快速模式（使用默认值）
#   ./scripts/config-wizard.sh --template   # 选择预设模板
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 加载颜色库
source "$SCRIPT_DIR/../lib/utils/colors.sh"

# =============================================================================
# 配置变量
# =============================================================================
CONFIG_OUTPUT_DIR="config"
CONFIG_FILE="central-config.yaml"

# 项目配置
PROJECT_NAME=""
PROJECT_VERSION="1.0.0"
PROJECT_DESC=""

# 构建配置
BUILD_TOOL="npm"
BUILD_CMD=""
BUILD_OUTPUT="dist"

# 测试配置
TEST_FRAMEWORK="jest"
TEST_COVERAGE_THRESHOLD=80

# 部署配置
DEPLOY_TARGET="docker"
DEPLOY_STRATEGY="rolling"
DEPLOY_REPLICAS=3

# 环境配置
ENVIRONMENTS=("development" "staging" "production")

# =============================================================================
# 辅助函数
# =============================================================================

# 显示欢迎信息
show_welcome() {
    clear
    print_header "CI/CD 配置向导"
    echo -e "${COLOR_INFO}欢迎使用 CI/CD 配置向导！${COLOR_NC}"
    echo -e "本向导将帮助您生成项目的 CI/CD 配置文件。"
    echo ""
    echo -e "${COLOR_DIM}按 Enter 继续，或按 Ctrl+C 退出${COLOR_NC}"
    read -r
}

# 提示用户输入
prompt() {
    local message="$1"
    local default="${2:-}"
    local result

    if [[ -n "$default" ]]; then
        echo -en "${COLOR_INFO}?${COLOR_NC} ${message} ${COLOR_DIM}[$default]${COLOR_NC}: "
    else
        echo -en "${COLOR_INFO}?${COLOR_NC} ${message}: "
    fi

    read -r result
    echo "${result:-$default}"
}

# 提示用户选择
prompt_select() {
    local message="$1"
    shift
    local options=("$@")
    local selected=0
    local key

    echo -e "${COLOR_INFO}?${COLOR_NC} ${message}"

    while true; do
        # 显示选项
        for i in "${!options[@]}"; do
            if [[ $i -eq $selected ]]; then
                echo -e "  ${COLOR_SUCCESS}❯${COLOR_NC} ${COLOR_BOLD}${options[$i]}${COLOR_NC}"
            else
                echo -e "    ${options[$i]}"
            fi
        done

        # 读取按键
        read -rsn1 key

        case "$key" in
            A) # 上箭头
                ((selected--)) || true
                [[ $selected -lt 0 ]] && selected=$((${#options[@]} - 1))
                ;;
            B) # 下箭头
                ((selected++)) || true
                [[ $selected -ge ${#options[@]} ]] && selected=0
                ;;
            "") # Enter
                break
                ;;
        esac

        # 清除选项显示
        for _ in "${options[@]}"; do
            echo -en "\033[1A\033[2K"
        done
    done

    echo "${options[$selected]}"
}

# 确认提示
confirm() {
    local message="$1"
    local default="${2:-y}"
    local result

    if [[ "$default" == "y" ]]; then
        echo -en "${COLOR_INFO}?${COLOR_NC} ${message} ${COLOR_DIM}[Y/n]${COLOR_NC}: "
    else
        echo -en "${COLOR_INFO}?${COLOR_NC} ${message} ${COLOR_DIM}[y/N]${COLOR_NC}: "
    fi

    read -r result
    result="${result:-$default}"

    [[ "$result" =~ ^[Yy] ]]
}

# 显示进度
show_progress() {
    local current="$1"
    local total="$2"
    local message="$3"

    local percent=$((current * 100 / total))
    local filled=$((percent / 5))
    local empty=$((20 - filled))

    echo -en "\r${COLOR_INFO}[${COLOR_NC}"
    printf '%*s' "$filled" '' | tr ' ' '█'
    printf '%*s' "$empty" '' | tr ' ' '░'
    echo -en "${COLOR_INFO}]${COLOR_NC} ${percent}% - ${message}"
}

# =============================================================================
# 配置步骤
# =============================================================================

# 步骤1: 项目基本信息
step_project_info() {
    echo ""
    print_header "步骤 1/5: 项目信息"

    PROJECT_NAME=$(prompt "项目名称" "$(basename "$PWD")")
    PROJECT_VERSION=$(prompt "项目版本" "1.0.0")
    PROJECT_DESC=$(prompt "项目描述" "My CI/CD project")

    echo ""
    print_success "项目信息已记录"
}

# 步骤2: 构建配置
step_build_config() {
    echo ""
    print_header "步骤 2/5: 构建配置"

    echo -e "${COLOR_INFO}选择构建工具:${COLOR_NC}"
    BUILD_TOOL=$(prompt_select "请选择构建工具" "npm" "yarn" "pnpm" "make" "gradle" "maven" "custom")

    case "$BUILD_TOOL" in
        npm|yarn|pnpm)
            BUILD_CMD="${BUILD_TOOL} run build"
            ;;
        make)
            BUILD_CMD="make build"
            ;;
        gradle)
            BUILD_CMD="./gradlew build"
            ;;
        maven)
            BUILD_CMD="mvn package"
            ;;
        custom)
            BUILD_CMD=$(prompt "请输入构建命令" "")
            ;;
    esac

    BUILD_OUTPUT=$(prompt "构建输出目录" "dist")

    echo ""
    print_success "构建配置已记录"
}

# 步骤3: 测试配置
step_test_config() {
    echo ""
    print_header "步骤 3/5: 测试配置"

    echo -e "${COLOR_INFO}选择测试框架:${COLOR_NC}"
    TEST_FRAMEWORK=$(prompt_select "请选择测试框架" "jest" "mocha" "pytest" "junit" "go test" "custom" "none")

    if [[ "$TEST_FRAMEWORK" != "none" ]]; then
        TEST_COVERAGE_THRESHOLD=$(prompt "测试覆盖率阈值 (%)" "80")
    fi

    echo ""
    print_success "测试配置已记录"
}

# 步骤4: 部署配置
step_deploy_config() {
    echo ""
    print_header "步骤 4/5: 部署配置"

    echo -e "${COLOR_INFO}选择部署目标:${COLOR_NC}"
    DEPLOY_TARGET=$(prompt_select "请选择部署目标" "docker" "kubernetes" "aws" "gcp" "azure" "local" "custom")

    echo -e "${COLOR_INFO}选择部署策略:${COLOR_NC}"
    DEPLOY_STRATEGY=$(prompt_select "请选择部署策略" "rolling" "blue-green" "canary" "recreate")

    DEPLOY_REPLICAS=$(prompt "副本数量" "3")

    echo ""
    print_success "部署配置已记录"
}

# 步骤5: 环境配置
step_env_config() {
    echo ""
    print_header "步骤 5/5: 环境配置"

    if confirm "是否使用默认环境 (development, staging, production)?"; then
        ENVIRONMENTS=("development" "staging" "production")
    else
        ENVIRONMENTS=()
        echo -e "${COLOR_INFO}输入环境名称 (每行一个，空行结束):${COLOR_NC}"
        while true; do
            local env
            read -r env
            [[ -z "$env" ]] && break
            ENVIRONMENTS+=("$env")
        done
    fi

    echo ""
    print_success "环境配置已记录"
}

# =============================================================================
# 生成配置文件
# =============================================================================

generate_config() {
    echo ""
    print_header "生成配置文件"

    mkdir -p "$CONFIG_OUTPUT_DIR/environment"

    # 生成主配置文件
    cat > "$CONFIG_OUTPUT_DIR/$CONFIG_FILE" << EOF
# =============================================================================
# CI/CD 中央配置文件
# 由配置向导自动生成于 $(date '+%Y-%m-%d %H:%M:%S')
# =============================================================================

# 项目信息
project:
  name: "$PROJECT_NAME"
  version: "$PROJECT_VERSION"
  description: "$PROJECT_DESC"

# 全局配置
global:
  log_level: "INFO"
  timezone: "Asia/Shanghai"
  timeout: 3600
  retry_count: 3

# 构建配置
build:
  tool: "$BUILD_TOOL"
  commands:
    - "${BUILD_CMD}"
  output_dir: "$BUILD_OUTPUT"
  cache:
    enabled: true
    paths:
      - "node_modules"
      - ".cache"

# 测试配置
test:
  framework: "$TEST_FRAMEWORK"
  coverage:
    enabled: true
    threshold: $TEST_COVERAGE_THRESHOLD
  commands:
EOF

    # 添加测试命令
    case "$TEST_FRAMEWORK" in
        jest)
            echo '    - "npm test"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        mocha)
            echo '    - "npm run test"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        pytest)
            echo '    - "pytest"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        junit)
            echo '    - "./gradlew test"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        "go test")
            echo '    - "go test ./..."' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        none)
            echo '    - "echo No tests configured"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
        *)
            echo '    - "npm test"' >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
            ;;
    esac

    cat >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE" << EOF

# 部署配置
deploy:
  target: "$DEPLOY_TARGET"
  strategy: "$DEPLOY_STRATEGY"
  replicas: $DEPLOY_REPLICAS
  rollback_enabled: true
  health_check:
    enabled: true
    path: "/health"
    interval: 30
    timeout: 10

# 回滚配置
rollback:
  enabled: true
  auto_rollback_on_failure: true
  keep_releases: 5
  strategies:
    - "$DEPLOY_STRATEGY"

# 安全配置
security:
  secret_scanning: true
  dependency_scanning: true
  iac_scanning: true
  vulnerability_threshold: "high"

# 监控配置
monitoring:
  enabled: true
  metrics_interval: 30
  alerts:
    enabled: true
    channels:
      - slack
      - email

# 环境列表
environments:
EOF

    # 添加环境
    for env in "${ENVIRONMENTS[@]}"; do
        echo "  - $env" >> "$CONFIG_OUTPUT_DIR/$CONFIG_FILE"
    done

    # 生成环境配置文件
    for env in "${ENVIRONMENTS[@]}"; do
        generate_env_config "$env"
    done

    print_success "配置文件已生成: $CONFIG_OUTPUT_DIR/$CONFIG_FILE"
}

# 生成环境配置文件
generate_env_config() {
    local env="$1"
    local env_file="$CONFIG_OUTPUT_DIR/environment/${env}.yaml"

    local debug="false"
    local log_level="INFO"
    local replicas="$DEPLOY_REPLICAS"

    case "$env" in
        development|dev)
            debug="true"
            log_level="DEBUG"
            replicas=1
            ;;
        staging|stage)
            debug="false"
            log_level="INFO"
            replicas=2
            ;;
        production|prod)
            debug="false"
            log_level="WARN"
            ;;
    esac

    cat > "$env_file" << EOF
# =============================================================================
# ${env} 环境配置
# =============================================================================

environment: "$env"

settings:
  debug: $debug
  log_level: "$log_level"

deploy:
  replicas: $replicas
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "200m"

# 环境变量
env_vars:
  NODE_ENV: "$env"
  LOG_LEVEL: "$log_level"
EOF

    print_info "环境配置已生成: $env_file"
}

# =============================================================================
# 显示摘要
# =============================================================================

show_summary() {
    echo ""
    print_header "配置摘要"

    echo -e "${COLOR_BOLD}项目信息:${COLOR_NC}"
    echo -e "  名称:     $PROJECT_NAME"
    echo -e "  版本:     $PROJECT_VERSION"
    echo -e "  描述:     $PROJECT_DESC"
    echo ""

    echo -e "${COLOR_BOLD}构建配置:${COLOR_NC}"
    echo -e "  工具:     $BUILD_TOOL"
    echo -e "  命令:     $BUILD_CMD"
    echo -e "  输出:     $BUILD_OUTPUT"
    echo ""

    echo -e "${COLOR_BOLD}测试配置:${COLOR_NC}"
    echo -e "  框架:     $TEST_FRAMEWORK"
    echo -e "  覆盖率:   ${TEST_COVERAGE_THRESHOLD}%"
    echo ""

    echo -e "${COLOR_BOLD}部署配置:${COLOR_NC}"
    echo -e "  目标:     $DEPLOY_TARGET"
    echo -e "  策略:     $DEPLOY_STRATEGY"
    echo -e "  副本:     $DEPLOY_REPLICAS"
    echo ""

    echo -e "${COLOR_BOLD}环境:${COLOR_NC}"
    for env in "${ENVIRONMENTS[@]}"; do
        echo -e "  - $env"
    done
    echo ""

    echo -e "${COLOR_BOLD}生成的文件:${COLOR_NC}"
    echo -e "  - $CONFIG_OUTPUT_DIR/$CONFIG_FILE"
    for env in "${ENVIRONMENTS[@]}"; do
        echo -e "  - $CONFIG_OUTPUT_DIR/environment/${env}.yaml"
    done
}

# =============================================================================
# 快速模式
# =============================================================================

quick_mode() {
    echo -e "${COLOR_INFO}快速模式：使用默认配置...${COLOR_NC}"

    PROJECT_NAME=$(basename "$PWD")
    PROJECT_VERSION="1.0.0"
    PROJECT_DESC="My CI/CD project"
    BUILD_TOOL="npm"
    BUILD_CMD="npm run build"
    BUILD_OUTPUT="dist"
    TEST_FRAMEWORK="jest"
    TEST_COVERAGE_THRESHOLD=80
    DEPLOY_TARGET="docker"
    DEPLOY_STRATEGY="rolling"
    DEPLOY_REPLICAS=3
    ENVIRONMENTS=("development" "staging" "production")

    generate_config
    show_summary
}

# =============================================================================
# 模板模式
# =============================================================================

template_mode() {
    echo ""
    print_header "选择项目模板"

    local template
    template=$(prompt_select "请选择项目模板" \
        "node-webapp (Node.js Web 应用)" \
        "node-api (Node.js API 服务)" \
        "python-api (Python FastAPI 服务)" \
        "go-service (Go 微服务)" \
        "java-spring (Java Spring Boot)")

    case "$template" in
        "node-webapp"*)
            BUILD_TOOL="npm"
            BUILD_CMD="npm run build"
            TEST_FRAMEWORK="jest"
            DEPLOY_TARGET="docker"
            ;;
        "node-api"*)
            BUILD_TOOL="npm"
            BUILD_CMD="npm run build"
            TEST_FRAMEWORK="jest"
            DEPLOY_TARGET="kubernetes"
            ;;
        "python-api"*)
            BUILD_TOOL="custom"
            BUILD_CMD="pip install -r requirements.txt"
            TEST_FRAMEWORK="pytest"
            DEPLOY_TARGET="docker"
            ;;
        "go-service"*)
            BUILD_TOOL="make"
            BUILD_CMD="go build -o app ."
            TEST_FRAMEWORK="go test"
            DEPLOY_TARGET="kubernetes"
            ;;
        "java-spring"*)
            BUILD_TOOL="gradle"
            BUILD_CMD="./gradlew build"
            TEST_FRAMEWORK="junit"
            DEPLOY_TARGET="kubernetes"
            ;;
    esac

    # 继续收集其他信息
    step_project_info
    step_deploy_config
    step_env_config
    generate_config
    show_summary
}

# =============================================================================
# 帮助信息
# =============================================================================

show_help() {
    cat << EOF
用法: $0 [选项]

CI/CD 交互式配置向导

选项:
  --quick       快速模式，使用默认配置
  --template    模板模式，选择预设模板
  -h, --help    显示此帮助信息

示例:
  $0                # 启动交互式向导
  $0 --quick        # 快速生成默认配置
  $0 --template     # 选择模板生成配置

EOF
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    case "${1:-}" in
        --help|-h)
            show_help
            exit 0
            ;;
        --quick)
            quick_mode
            ;;
        --template)
            template_mode
            ;;
        "")
            show_welcome
            step_project_info
            step_build_config
            step_test_config
            step_deploy_config
            step_env_config

            echo ""
            if confirm "是否生成配置文件?"; then
                generate_config
                show_summary
                echo ""
                print_success "配置向导完成！"
                echo -e "运行 ${COLOR_BOLD}aicd validate${COLOR_NC} 验证配置"
            else
                print_warning "已取消配置生成"
            fi
            ;;
        *)
            echo -e "${COLOR_ERROR}未知选项: $1${COLOR_NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
