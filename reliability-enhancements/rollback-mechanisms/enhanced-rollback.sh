#!/bin/bash

# 增强版回滚脚本
# 整合蓝绿部署、金丝雀部署和基于指标的自动回滚功能

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
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
ROLLBACK_STRATEGY="standard"  # standard, blue-green, canary
ACTIVE_ENV=""  # 当前活跃环境 (blue|green)，仅在蓝绿部署时使用
KUBECONFIG=""
HEALTH_CHECK="true"
HEALTH_CHECK_TYPE="comprehensive"
STRATEGY_CONFIG=""
NOTIFY_ON_ROLLBACK="true"
ROLLBACK_REASON=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

增强版回滚脚本

选项:
  -t, --target TARGET         部署目标 (kubernetes, docker-compose) [默认: kubernetes]
  -a, --app NAME              应用名称
  -n, --namespace NS          Kubernetes命名空间 [默认: default]
  -v, --version VER           回滚到指定版本 [默认: previous]
  -s, --steps NUM             回滚步数 [默认: 1]
  --strategy STRATEGY         回滚策略 (standard, blue-green, canary) [默认: standard]
  --active-env ENV            当前活跃环境 (blue|green)，仅在蓝绿部署时使用
  -k, --kubeconfig PATH       Kubernetes配置文件路径
  --health-check TYPE         健康检查类型 (true, false, basic, comprehensive) [默认: comprehensive]
  --strategy-config FILE      回滚策略配置文件路径
  --notify                    是否在回滚时发送通知 [默认: true]
  -r, --reason REASON         回滚原因
  -h, --help                  显示此帮助信息

示例:
  $0 -t kubernetes -a myapp -n production
  $0 --target kubernetes --app myapp --strategy blue-green --active-env blue
  $0 -a myapp --strategy canary --strategy-config ./rollback-strategy-config.yaml

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
        --strategy)
            ROLLBACK_STRATEGY="$2"
            shift 2
            ;;
        --active-env)
            ACTIVE_ENV="$2"
            shift 2
            ;;
        -k|--kubeconfig)
            KUBECONFIG="$2"
            shift 2
            ;;
        --health-check)
            HEALTH_CHECK="$2"
            shift 2
            ;;
        --strategy-config)
            STRATEGY_CONFIG="$2"
            shift 2
            ;;
        --notify)
            NOTIFY_ON_ROLLBACK="$2"
            shift 2
            ;;
        -r|--reason)
            ROLLBACK_REASON="$2"
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
    
    if [ "$DEPLOY_TARGET" != "kubernetes" ] && [ "$DEPLOY_TARGET" != "docker-compose" ]; then
        log_error "部署目标必须是 kubernetes 或 docker-compose"
        show_help
        exit 1
    fi
    
    if [ "$ROLLBACK_STRATEGY" != "standard" ] && [ "$ROLLBACK_STRATEGY" != "blue-green" ] && [ "$ROLLBACK_STRATEGY" != "canary" ]; then
        log_error "回滚策略必须是 standard, blue-green 或 canary"
        show_help
        exit 1
    fi
    
    if [ "$ROLLBACK_STRATEGY" == "blue-green" ] && [ -z "$ACTIVE_ENV" ]; then
        log_error "蓝绿部署回滚必须指定当前活跃环境"
        show_help
        exit 1
    fi
    
    if [ -n "$KUBECONFIG" ] && [ ! -f "$KUBECONFIG" ]; then
        log_error "Kubernetes配置文件不存在: $KUBECONFIG"
        exit 1
    fi
    
    if [ -n "$STRATEGY_CONFIG" ] && [ ! -f "$STRATEGY_CONFIG" ]; then
        log_error "策略配置文件不存在: $STRATEGY_CONFIG"
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

# 设置Kubernetes配置
setup_kubeconfig() {
    if [ -n "$KUBECONFIG" ]; then
        export KUBECONFIG="$KUBECONFIG"
    fi
    
    # 验证kubectl可用性
    check_command "kubectl"
    
    # 验证连接
    if ! kubectl cluster-info &> /dev/null; then
        log_error "无法连接到Kubernetes集群"
        exit 1
    fi
}

# 发送通知
send_notification() {
    local message="$1"
    
    if [ "$NOTIFY_ON_ROLLBACK" == "true" ]; then
        log_info "发送回滚通知: $message"
        
        # 这里可以集成实际的通知系统
        # 例如：Slack、Email、Webhook等
        echo "NOTIFICATION: $message" >> /tmp/rollback-notifications.log
        
        # 如果配置了策略文件，可以从中读取通知配置
        if [ -n "$STRATEGY_CONFIG" ]; then
            log_info "使用策略配置文件中的通知设置"
            # 实际实现中会解析YAML配置并发送通知
        fi
    fi
}

# 执行健康检查
perform_health_check() {
    if [ "$HEALTH_CHECK" == "false" ]; then
        log_info "跳过健康检查"
        return 0
    fi
    
    log_info "执行回滚前健康检查..."
    
    # 根据部署目标和策略执行相应的健康检查
    case $DEPLOY_TARGET in
        kubernetes)
            # 使用专门的健康检查脚本
            local health_check_script="/root/idear/cicd-solution/reliability-enhancements/rollback-mechanisms/health-check.sh"
            if [ -f "$health_check_script" ]; then
                local check_type="comprehensive"
                if [ "$HEALTH_CHECK" == "basic" ]; then
                    check_type="basic"
                fi
                
                if $health_check_script -a "$APP_NAME" -n "$NAMESPACE" -k "$KUBECONFIG" -t "$check_type"; then
                    log_info "健康检查通过"
                    return 0
                else
                    log_error "健康检查失败"
                    return 1
                fi
            else
                log_warn "健康检查脚本不存在，跳过健康检查"
                return 0
            fi
            ;;
        *)
            log_warn "不支持的部署目标的健康检查，跳过"
            return 0
            ;;
    esac
}

# 标准Kubernetes回滚
rollback_kubernetes_standard() {
    log "开始标准Kubernetes回滚..."
    
    local deployment_name="${APP_NAME}-deployment"
    
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
    local deployment_name="${APP_NAME}-deployment"
    
    # 执行回滚操作
    if kubectl rollout undo deployment/$deployment_name -n $NAMESPACE --to-revision=$ROLLBACK_STEPS; then
        log "Kubernetes回滚操作已启动"
        
        # 等待回滚完成
        kubectl rollout status deployment/$deployment_name -n $NAMESPACE
        
        # 检查回滚状态
        if kubectl get deployment/$deployment_name -n $NAMESPACE | grep -q "available"; then
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
    local deployment_name="${APP_NAME}-deployment"
    
    # 获取指定版本的修订号
    local REVISION
    REVISION=$(kubectl rollout history deployment/$deployment_name -n $NAMESPACE | grep $ROLLBACK_VERSION | awk '{print $1}')
    
    if [ -z "$REVISION" ]; then
        log_error "未找到指定版本: $ROLLBACK_VERSION"
        exit 1
    fi
    
    # 执行回滚操作
    if kubectl rollout undo deployment/$deployment_name -n $NAMESPACE --to-revision=$REVISION; then
        log "Kubernetes回滚到版本 $ROLLBACK_VERSION 操作已启动"
        
        # 等待回滚完成
        kubectl rollout status deployment/$deployment_name -n $NAMESPACE
        
        # 检查回滚状态
        if kubectl get deployment/$deployment_name -n $NAMESPACE | grep -q "available"; then
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

# 蓝绿部署回滚
rollback_kubernetes_blue_green() {
    log "开始蓝绿部署回滚..."
    
    # 使用专门的蓝绿回滚脚本
    local bg_rollback_script="/root/idear/cicd-solution/reliability-enhancements/rollback-mechanisms/blue-green-rollback.sh"
    if [ -f "$bg_rollback_script" ]; then
        local cmd="$bg_rollback_script -a $APP_NAME -n $NAMESPACE -e $ACTIVE_ENV"
        if [ -n "$KUBECONFIG" ]; then
            cmd="$cmd -k $KUBECONFIG"
        fi
        if [ -n "$ROLLBACK_REASON" ]; then
            cmd="$cmd -r '$ROLLBACK_REASON'"
        fi
        
        if eval $cmd; then
            log "蓝绿部署回滚成功"
        else
            log_error "蓝绿部署回滚失败"
            exit 1
        fi
    else
        log_error "蓝绿回滚脚本不存在: $bg_rollback_script"
        exit 1
    fi
}

# 金丝雀部署回滚
rollback_kubernetes_canary() {
    log "开始金丝雀部署回滚..."
    
    # 使用专门的金丝雀回滚脚本
    local canary_rollback_script="/root/idear/cicd-solution/reliability-enhancements/rollback-mechanisms/canary-rollback.sh"
    if [ -f "$canary_rollback_script" ]; then
        local cmd="$canary_rollback_script -a $APP_NAME -n $NAMESPACE"
        if [ -n "$KUBECONFIG" ]; then
            cmd="$cmd -k $KUBECONFIG"
        fi
        if [ -n "$STRATEGY_CONFIG" ]; then
            # 从配置文件中读取阈值设置
            # 这里简化处理，实际应用中需要解析YAML
            cmd="$cmd --cpu-threshold 80 --memory-threshold 80"
        fi
        if [ -n "$ROLLBACK_REASON" ]; then
            cmd="$cmd -r '$ROLLBACK_REASON'"
        fi
        
        if eval $cmd; then
            log "金丝雀部署回滚成功"
        else
            log_error "金丝雀部署回滚失败"
            exit 1
        fi
    else
        log_error "金丝雀回滚脚本不存在: $canary_rollback_script"
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
    log "开始执行增强版回滚流程"
    log "部署目标: $DEPLOY_TARGET"
    log "应用名称: $APP_NAME"
    log "回滚策略: $ROLLBACK_STRATEGY"
    log "回滚版本: $ROLLBACK_VERSION"
    if [ -n "$ROLLBACK_REASON" ]; then
        log "回滚原因: $ROLLBACK_REASON"
    fi
    
    # 验证参数
    validate_params
    
    # 执行健康检查
    if ! perform_health_check; then
        log_error "回滚前健康检查失败，终止回滚操作"
        send_notification "回滚操作因健康检查失败而终止: $APP_NAME"
        exit 1
    fi
    
    # 发送回滚开始通知
    send_notification "开始回滚操作: $APP_NAME (策略: $ROLLBACK_STRATEGY)"
    
    # 根据部署目标和策略执行回滚
    case $DEPLOY_TARGET in
        kubernetes)
            setup_kubeconfig
            
            case $ROLLBACK_STRATEGY in
                standard)
                    rollback_kubernetes_standard
                    ;;
                blue-green)
                    rollback_kubernetes_blue_green
                    ;;
                canary)
                    rollback_kubernetes_canary
                    ;;
                *)
                    log_error "不支持的回滚策略: $ROLLBACK_STRATEGY"
                    exit 1
                    ;;
            esac
            ;;
        docker-compose)
            rollback_docker_compose
            ;;
        *)
            log_error "不支持的部署目标: $DEPLOY_TARGET"
            exit 1
            ;;
    esac
    
    # 发送回滚完成通知
    send_notification "回滚操作完成: $APP_NAME (策略: $ROLLBACK_STRATEGY)"
    
    log "增强版回滚流程完成"
}

# 执行主函数
main "$@"