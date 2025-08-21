#!/bin/bash

# 通用回滚脚本
# 支持多种部署目标的回滚操作

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
DEPLOY_TARGET="kubernetes"
APP_NAME=""
NAMESPACE="default"
ROLLBACK_VERSION="previous"
ROLLBACK_STEPS=1

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

通用回滚脚本

选项:
  -t, --target TARGET    部署目标 (kubernetes, docker-compose) [默认: kubernetes]
  -a, --app NAME         应用名称
  -n, --namespace NS     Kubernetes命名空间 [默认: default]
  -v, --version VER      回滚到指定版本 [默认: previous]
  -s, --steps NUM        回滚步数 [默认: 1]
  -h, --help             显示此帮助信息

示例:
  $0 -t kubernetes -a myapp -n production
  $0 --target docker-compose --app myapp --version v1.0.0

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            DEPLOY_TARGET="$2"
            shift 2
            ;;
        -a|--app)
            APP_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -v|--version)
            ROLLBACK_VERSION="$2"
            shift 2
            ;;
        -s|--steps)
            ROLLBACK_STEPS="$2"
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

# 验证必要参数
validate_params() {
    if [ -z "$APP_NAME" ]; then
        log_error "必须指定应用名称"
        show_help
        exit 1
    fi
}

# 检查必要命令
check_command() {
    if ! command -v $1 &> /dev/null; then
        log_error "缺少必要命令: $1"
        exit 1
    fi
}

# Kubernetes回滚
rollback_kubernetes() {
    log "开始Kubernetes回滚..."
    
    check_command "kubectl"
    
    # 根据回滚版本执行不同操作
    case $ROLLBACK_VERSION in
        previous)
            rollback_kubernetes_previous
            ;;
        *)
            rollback_kubernetes_to_version
            ;;
    esac
}

# Kubernetes回滚到上一版本
rollback_kubernetes_previous() {
    log "回滚到上一版本..."
    
    # 执行回滚操作
    if kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE --to-revision=$ROLLBACK_STEPS; then
        log "Kubernetes回滚操作已启动"
        
        # 等待回滚完成
        kubectl rollout status deployment/$APP_NAME -n $NAMESPACE
        
        # 检查回滚状态
        if kubectl get deployment/$APP_NAME -n $NAMESPACE | grep -q "available"; then
            log "Kubernetes回滚成功"
        else
            log_error "Kubernetes回滚失败"
            exit 1
        fi
    else
        log_error "Kubernetes回滚操作失败"
        exit 1
    fi
}

# Kubernetes回滚到指定版本
rollback_kubernetes_to_version() {
    log "回滚到指定版本: $ROLLBACK_VERSION"
    
    # 获取指定版本的修订号
    REVISION=$(kubectl rollout history deployment/$APP_NAME -n $NAMESPACE | grep $ROLLBACK_VERSION | awk '{print $1}')
    
    if [ -z "$REVISION" ]; then
        log_error "未找到指定版本: $ROLLBACK_VERSION"
        exit 1
    fi
    
    # 执行回滚操作
    if kubectl rollout undo deployment/$APP_NAME -n $NAMESPACE --to-revision=$REVISION; then
        log "Kubernetes回滚到版本 $ROLLBACK_VERSION 操作已启动"
        
        # 等待回滚完成
        kubectl rollout status deployment/$APP_NAME -n $NAMESPACE
        
        # 检查回滚状态
        if kubectl get deployment/$APP_NAME -n $NAMESPACE | grep -q "available"; then
            log "Kubernetes回滚到版本 $ROLLBACK_VERSION 成功"
        else
            log_error "Kubernetes回滚到版本 $ROLLBACK_VERSION 失败"
            exit 1
        fi
    else
        log_error "Kubernetes回滚到版本 $ROLLBACK_VERSION 操作失败"
        exit 1
    fi
}

# Docker Compose回滚
rollback_docker_compose() {
    log "开始Docker Compose回滚..."
    
    check_command "docker-compose"
    
    # 检查是否存在之前的版本
    if [ -f "docker-compose.previous.yml" ]; then
        # 停止当前服务
        docker-compose down
        
        # 备份当前配置
        cp docker-compose.yml docker-compose.rollback.yml
        
        # 恢复之前版本的配置
        cp docker-compose.previous.yml docker-compose.yml
        
        # 启动服务
        docker-compose up -d
        
        # 检查服务状态
        if docker-compose ps | grep -q "Up"; then
            log "Docker Compose回滚成功"
        else
            log_error "Docker Compose回滚失败"
            exit 1
        fi
    else
        log_error "未找到之前的版本配置文件"
        exit 1
    fi
}

# 主回滚流程
main() {
    log "开始执行回滚流程"
    log "部署目标: $DEPLOY_TARGET"
    log "应用名称: $APP_NAME"
    log "回滚版本: $ROLLBACK_VERSION"
    log "回滚步数: $ROLLBACK_STEPS"
    
    # 验证参数
    validate_params
    
    # 根据部署目标执行回滚
    case $DEPLOY_TARGET in
        kubernetes)
            rollback_kubernetes
            ;;
        docker-compose)
            rollback_docker_compose
            ;;
        *)
            log_error "不支持的部署目标: $DEPLOY_TARGET"
            exit 1
            ;;
    esac
    
    log "回滚流程完成"
}

# 执行主函数
main "$@"