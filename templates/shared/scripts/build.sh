#!/bin/bash

# 通用构建脚本
# 支持多种项目类型的构建流程

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
BUILD_DIR="."
OUTPUT_DIR="dist"
NODE_VERSION="18"
PYTHON_VERSION="3.9"

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

通用构建脚本

选项:
  -t, --type TYPE        项目类型 (nodejs, python, java, go) [默认: nodejs]
  -s, --source DIR       源代码目录 [默认: .]
  -o, --output DIR       输出目录 [默认: dist]
  -n, --node-version VER Node.js版本 [默认: 18]
  -p, --python-version   Python版本 [默认: 3.9]
  -h, --help             显示此帮助信息

示例:
  $0 -t nodejs -s ./src -o ./build
  $0 --type python --source ./app --output ./dist

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            PROJECT_TYPE="$2"
            shift 2
            ;;
        -s|--source)
            BUILD_DIR="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--node-version)
            NODE_VERSION="$2"
            shift 2
            ;;
        -p|--python-version)
            PYTHON_VERSION="$2"
            shift 2
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

# Node.js项目构建
build_nodejs() {
    log "开始构建Node.js项目..."
    
    check_command "node"
    check_command "npm"
    
    # 检查Node.js版本
    CURRENT_NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$CURRENT_NODE_VERSION" != "$NODE_VERSION" ]; then
        log_warn "当前Node.js版本($CURRENT_NODE_VERSION)与要求版本($NODE_VERSION)不匹配"
    fi
    
    # 安装依赖
    log "安装依赖..."
    npm ci
    
    # 运行构建
    log "运行构建..."
    if npm run build; then
        log "Node.js项目构建成功"
    else
        log_error "Node.js项目构建失败"
        exit 1
    fi
}

# Python项目构建
build_python() {
    log "开始构建Python项目..."
    
    check_command "python$PYTHON_VERSION"
    check_command "pip$PYTHON_VERSION"
    
    # 创建虚拟环境
    log "创建虚拟环境..."
    python$PYTHON_VERSION -m venv venv
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 安装依赖
    log "安装依赖..."
    pip install -r requirements.txt
    
    # 运行构建（如果存在setup.py）
    if [ -f "setup.py" ]; then
        log "运行构建..."
        python setup.py build
    else
        log "未找到setup.py，跳过构建步骤"
    fi
    
    log "Python项目构建完成"
    
    # 离虚拟环境
    deactivate
}

# 构建后处理
post_build() {
    log "执行构建后处理..."
    
    # 创建输出目录
    mkdir -p "$OUTPUT_DIR"
    
    # 复制构建产物
    case $PROJECT_TYPE in
        nodejs)
            if [ -d "dist" ]; then
                cp -r dist/* "$OUTPUT_DIR/"
            elif [ -d "build" ]; then
                cp -r build/* "$OUTPUT_DIR/"
            else
                log_warn "未找到标准构建输出目录"
            fi
            ;;
        python)
            # Python项目通常不需要额外的后处理
            ;;
        *)
            log_warn "未知项目类型: $PROJECT_TYPE"
            ;;
    esac
    
    log "构建后处理完成"
}

# 主构建流程
main() {
    log "开始执行构建流程"
    log "项目类型: $PROJECT_TYPE"
    log "源代码目录: $BUILD_DIR"
    log "输出目录: $OUTPUT_DIR"
    
    # 切换到构建目录
    cd "$BUILD_DIR" || {
        log_error "无法切换到目录: $BUILD_DIR"
        exit 1
    }
    
    # 根据项目类型执行构建
    case $PROJECT_TYPE in
        nodejs)
            build_nodejs
            ;;
        python)
            build_python
            ;;
        *)
            log_error "不支持的项目类型: $PROJECT_TYPE"
            exit 1
            ;;
    esac
    
    # 执行构建后处理
    post_build
    
    log "构建流程完成"
}

# 执行主函数
main "$@"