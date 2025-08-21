#!/bin/bash

# 通用部署脚本
# 支持多种部署目标和策略

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
IMAGE_NAME=""
IMAGE_TAG=""
NAMESPACE="default"
DEPLOY_STRATEGY="rolling"
REPLICAS=3

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

通用部署脚本

选项:
  -t, --target TARGET    部署目标 (kubernetes, docker-compose, ssh) [默认: kubernetes]
  -i, --image NAME       镜像名称
  -g, --tag TAG          镜像标签
  -n, --namespace NS     Kubernetes命名空间 [默认: default]
  -s, --strategy STRAT   部署策略 (rolling, blue-green, canary) [默认: rolling]
  -r, --replicas NUM     副本数量 [默认: 3]
  -h, --help             显示此帮助信息

示例:
  $0 -t kubernetes -i myapp -g v1.0.0 -n production
  $0 --target docker-compose --image myapp --tag latest

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--target)
            DEPLOY_TARGET="$2"
            shift 2
            ;;
        -i|--image)
            IMAGE_NAME="$2"
            shift 2
            ;;
        -g|--tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--strategy)
            DEPLOY_STRATEGY="$2"
            shift 2
            ;;
        -r|--replicas)
            REPLICAS="$2"
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
    if [ -z "$IMAGE_NAME" ]; then
        log_error "必须指定镜像名称"
        show_help
        exit 1
    fi
    
    if [ -z "$IMAGE_TAG" ]; then
        log_error "必须指定镜像标签"
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

# Kubernetes部署
deploy_kubernetes() {
    log "开始Kubernetes部署..."
    
    check_command "kubectl"
    
    # 根据部署策略执行不同操作
    case $DEPLOY_STRATEGY in
        rolling)
            deploy_kubernetes_rolling
            ;;
        blue-green)
            deploy_kubernetes_blue_green
            ;;
        canary)
            deploy_kubernetes_canary
            ;;
        *)
            log_error "不支持的部署策略: $DEPLOY_STRATEGY"
            exit 1
            ;;
    esac
}

# Kubernetes滚动更新部署
deploy_kubernetes_rolling() {
    log "执行滚动更新部署..."
    
    # 设置镜像
    kubectl set image deployment/$IMAGE_NAME $IMAGE_NAME=$IMAGE_NAME:$IMAGE_TAG -n $NAMESPACE
    
    # 等待部署完成
    kubectl rollout status deployment/$IMAGE_NAME -n $NAMESPACE
    
    # 检查部署状态
    if kubectl get deployment/$IMAGE_NAME -n $NAMESPACE | grep -q "available"; then
        log "Kubernetes滚动更新部署成功"
    else
        log_error "Kubernetes滚动更新部署失败"
        exit 1
    fi
}

# Kubernetes蓝绿部署
deploy_kubernetes_blue_green() {
    log "执行蓝绿部署..."
    
    # 检查绿色环境是否存在
    if kubectl get deployment/${IMAGE_NAME}-green -n $NAMESPACE &> /dev/null; then
        # 切换流量到绿色环境
        kubectl patch service/$IMAGE_NAME -p '{"spec":{"selector":{"version":"green"}}}' -n $NAMESPACE
        # 删除蓝色环境
        kubectl delete deployment/${IMAGE_NAME}-blue -n $NAMESPACE
        # 重命名绿色环境为蓝色环境
        kubectl patch deployment/${IMAGE_NAME}-green -p '{"metadata":{"name":"${IMAGE_NAME}-blue"}}' -n $NAMESPACE
    else
        # 部署到绿色环境
        kubectl create deployment ${IMAGE_NAME}-green -n $NAMESPACE --image=$IMAGE_NAME:$IMAGE_TAG
        kubectl scale deployment/${IMAGE_NAME}-green -n $NAMESPACE --replicas=$REPLICAS
        # 等待部署完成
        kubectl rollout status deployment/${IMAGE_NAME}-green -n $NAMESPACE
        # 切换流量到绿色环境
        kubectl patch service/$IMAGE_NAME -p '{"spec":{"selector":{"version":"green"}}}' -n $NAMESPACE
        # 删除蓝色环境
        kubectl delete deployment/${IMAGE_NAME}-blue -n $NAMESPACE 2>/dev/null || true
    fi
    
    log "Kubernetes蓝绿部署完成"
}

# Docker Compose部署
deploy_docker_compose() {
    log "开始Docker Compose部署..."
    
    check_command "docker-compose"
    
    # 生成docker-compose文件
    cat > docker-compose.yml << EOF
version: '3.8'
services:
  $IMAGE_NAME:
    image: $IMAGE_NAME:$IMAGE_TAG
    ports:
      - "8080:8080"
    environment:
      - ENV=production
    deploy:
      replicas: $REPLICAS
EOF
    
    # 部署应用
    docker-compose up -d
    
    # 检查服务状态
    if docker-compose ps | grep -q "Up"; then
        log "Docker Compose部署成功"
    else
        log_error "Docker Compose部署失败"
        exit 1
    fi
}

# SSH部署
deploy_ssh() {
    log "开始SSH部署..."
    
    check_command "ssh"
    check_command "scp"
    
    # 这里需要根据具体环境实现SSH部署逻辑
    log_warn "SSH部署逻辑需要根据具体环境实现"
    
    log "SSH部署完成"
}

# 主部署流程
main() {
    log "开始执行部署流程"
    log "部署目标: $DEPLOY_TARGET"
    log "镜像名称: $IMAGE_NAME"
    log "镜像标签: $IMAGE_TAG"
    log "部署策略: $DEPLOY_STRATEGY"
    
    # 验证参数
    validate_params
    
    # 根据部署目标执行部署
    case $DEPLOY_TARGET in
        kubernetes)
            deploy_kubernetes
            ;;
        docker-compose)
            deploy_docker_compose
            ;;
        ssh)
            deploy_ssh
            ;;
        *)
            log_error "不支持的部署目标: $DEPLOY_TARGET"
            exit 1
            ;;
    esac
    
    log "部署流程完成"
}

# 执行主函数
main "$@"