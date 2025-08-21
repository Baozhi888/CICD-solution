#!/bin/bash

# 通用测试脚本
# 支持多种项目类型的测试流程

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# 默认参数
PROJECT_TYPE="nodejs"
TEST_TYPE="all"
COVERAGE=false
COVERAGE_THRESHOLD=80

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

通用测试脚本

选项:
  -t, --type TYPE        项目类型 (nodejs, python, java, go) [默认: nodejs]
  -s, --test-type TYPE   测试类型 (unit, integration, e2e, all) [默认: all]
  -c, --coverage         生成测试覆盖率报告
  -h, --help             显示此帮助信息

示例:
  $0 -t nodejs -s unit
  $0 --type python --test-type integration --coverage

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -s|--test-type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -c|--coverage)
            COVERAGE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查必要命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "缺少必要命令: $1"
        exit 1
    fi
}

# 运行单元测试
run_unit_tests() {
    log "运行单元测试..."
    
    case $PROJECT_TYPE in
        nodejs)
            if [ "$COVERAGE" = true ]; then
                npm run test:unit -- --coverage
            else
                npm run test:unit
            fi
            ;;
        python)
            if [ "$COVERAGE" = true ]; then
                python -m pytest tests/unit --cov=.
            else
                python -m pytest tests/unit
            fi
            ;;
        *)
            log_error "不支持的项目类型: $PROJECT_TYPE"
            exit 1
            ;;
    esac
}

# 运行集成测试
run_integration_tests() {
    log "运行集成测试..."
    
    case $PROJECT_TYPE in
        nodejs)
            npm run test:integration
            ;;
        python)
            python -m pytest tests/integration
            ;;
        *)
            log_error "不支持的项目类型: $PROJECT_TYPE"
            exit 1
            ;;
    esac
}

# 运行端到端测试
run_e2e_tests() {
    log "运行端到端测试..."
    
    case $PROJECT_TYPE in
        nodejs)
            npm run test:e2e
            ;;
        python)
            python -m pytest tests/e2e
            ;;
        *)
            log_error "不支持的项目类型: $PROJECT_TYPE"
            exit 1
            ;;
    esac
}

# 检查测试覆盖率
check_coverage() {
    if [ "$COVERAGE" = true ]; then
        log "检查测试覆盖率..."
        
        case $PROJECT_TYPE in
            nodejs)
                # 检查覆盖率是否达到阈值
                COVERAGE_PERCENT=$(lcov --summary coverage/lcov.info | grep -o '[0-9]*%' | head -1 | tr -d '%')
                if [ "$COVERAGE_PERCENT" -lt "$COVERAGE_THRESHOLD" ]; then
                    log_error "测试覆盖率($COVERAGE_PERCENT%)低于阈值($COVERAGE_THRESHOLD%)"
                    exit 1
                else
                    log "测试覆盖率($COVERAGE_PERCENT%)满足要求"
                fi
                ;;
            python)
                # Python覆盖率检查
                coverage report --fail-under=$COVERAGE_THRESHOLD
                ;;
        esac
    fi
}

# 主测试流程
main() {
    log "开始执行测试流程"
    log "项目类型: $PROJECT_TYPE"
    log "测试类型: $TEST_TYPE"
    log "生成覆盖率报告: $COVERAGE"
    
    # 根据测试类型执行测试
    case $TEST_TYPE in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        e2e)
            run_e2e_tests
            ;;
        all)
            run_unit_tests
            run_integration_tests
            run_e2e_tests
            ;;
        *)
            log_error "不支持的测试类型: $TEST_TYPE"
            exit 1
            ;;
    esac
    
    # 检查测试覆盖率
    check_coverage
    
    log "测试流程完成"
}

# 执行主函数
main "$@"