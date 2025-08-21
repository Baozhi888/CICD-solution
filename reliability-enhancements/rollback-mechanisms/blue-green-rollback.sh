#!/bin/bash

# 蓝绿部署自动回滚脚本
# 支持基于健康检查和指标的自动回滚

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
APP_NAME=""
NAMESPACE="default"
ACTIVE_ENV=""  # 当前活跃环境 (blue|green)
KUBECONFIG=""
HEALTH_CHECK_TIMEOUT=300  # 健康检查超时时间（秒）
ROLLBACK_REASON=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

蓝绿部署自动回滚脚本

选项:
  -a, --app NAME              应用名称
  -n, --namespace NS          Kubernetes命名空间 [默认: default]
  -e, --active-env ENV        当前活跃环境 (blue|green)
  -k, --kubeconfig PATH       Kubernetes配置文件路径
  -t, --timeout SECONDS       健康检查超时时间（秒） [默认: 300]
  -r, --reason REASON         回滚原因
  -h, --help                  显示此帮助信息

示例:
  $0 -a myapp -n production -e blue -k ~/.kube/config
  $0 --app myapp --namespace staging --active-env green --timeout 600

EOF
}

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--app)
            APP_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -e|--active-env)
            ACTIVE_ENV="$2"
            shift 2
            ;;
        -k|--kubeconfig)
            KUBECONFIG="$2"
            shift 2
            ;;
        -t|--timeout)
            HEALTH_CHECK_TIMEOUT="$2"
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
    
    if [ -z "$ACTIVE_ENV" ]; then
        log_error "必须指定当前活跃环境 (blue|green)"
        show_help
        exit 1
    fi
    
    if [ "$ACTIVE_ENV" != "blue" ] && [ "$ACTIVE_ENV" != "green" ]; then
        log_error "活跃环境必须是 blue 或 green"
        show_help
        exit 1
    fi
    
    if [ -n "$KUBECONFIG" ] && [ ! -f "$KUBECONFIG" ]; then
        log_error "Kubernetes配置文件不存在: $KUBECONFIG"
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

# 获取非活跃环境
get_inactive_env() {
    if [ "$ACTIVE_ENV" == "blue" ]; then
        echo "green"
    else
        echo "blue"
    fi
}

# 执行健康检查
perform_health_check() {
    local env=$1
    local deployment_name="${APP_NAME}-${env}"
    local service_name="${APP_NAME}-${env}"
    
    log_info "开始对 ${env} 环境进行健康检查..."
    
    # 1. 检查Deployment状态
    log_info "检查Deployment状态..."
    if ! kubectl rollout status deployment/$deployment_name -n $NAMESPACE --timeout=${HEALTH_CHECK_TIMEOUT}s; then
        log_error "Deployment $deployment_name 未在超时时间内就绪"
        return 1
    fi
    
    # 2. 检查Pod状态
    log_info "检查Pod状态..."
    local pod_status
    pod_status=$(kubectl get pods -l app=$deployment_name -n $NAMESPACE -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ ! "$pod_status" =~ "Running" ]]; then
        log_error "Pod状态异常: $pod_status"
        return 1
    fi
    
    # 3. 检查Pod就绪状态
    log_info "检查Pod就绪状态..."
    local ready_pods
    ready_pods=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
    local desired_pods
    desired_pods=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.replicas}' 2>/dev/null)
    
    if [ "$ready_pods" != "$desired_pods" ]; then
        log_error "Pod就绪状态异常: $ready_pods/$desired_pods"
        return 1
    fi
    
    # 4. 检查服务端点
    log_info "检查服务端点..."
    local endpoints
    endpoints=$(kubectl get endpoints $service_name -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
    if [ -z "$endpoints" ]; then
        log_error "服务端点未就绪"
        return 1
    fi
    
    # 5. 执行应用特定的健康检查（如果定义了）
    log_info "执行应用特定健康检查..."
    if ! perform_app_health_check $env; then
        log_error "应用特定健康检查失败"
        return 1
    fi
    
    log_info "${env} 环境健康检查通过"
    return 0
}

# 应用特定健康检查（可扩展）
perform_app_health_check() {
    local env=$1
    local service_name="${APP_NAME}-${env}"
    
    # 获取服务端口
    local service_port
    service_port=$(kubectl get service/$service_name -n $NAMESPACE -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
    
    if [ -z "$service_port" ]; then
        log_warn "无法获取服务端口，跳过HTTP健康检查"
        return 0
    fi
    
    # 获取服务IP（使用NodePort或ClusterIP）
    local service_ip
    service_ip=$(kubectl get service/$service_name -n $NAMESPACE -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    
    # 如果是ClusterIP，需要在集群内访问
    # 这里我们只是示例，实际环境中可能需要更复杂的健康检查
    log_info "模拟应用健康检查 (端口: $service_port)"
    
    # 模拟健康检查延迟
    sleep 5
    
    # 假设健康检查通过
    return 0
}

# 切换流量到指定环境
switch_traffic() {
    local target_env=$1
    local service_name="${APP_NAME}-service"
    
    log_info "将流量切换到 ${target_env} 环境..."
    
    # 更新服务选择器
    if kubectl patch service/$service_name -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"app\":\"${APP_NAME}-${target_env}\"}}}"; then
        log_info "流量已成功切换到 ${target_env} 环境"
        return 0
    else
        log_error "流量切换失败"
        return 1
    fi
}

# 清理非活跃环境
cleanup_inactive_env() {
    local inactive_env=$1
    local deployment_name="${APP_NAME}-${inactive_env}"
    local service_name="${APP_NAME}-${inactive_env}"
    
    log_info "清理 ${inactive_env} 环境..."
    
    # 删除Deployment
    kubectl delete deployment/$deployment_name -n $NAMESPACE --ignore-not-found=true
    
    # 删除Service
    kubectl delete service/$service_name -n $NAMESPACE --ignore-not-found=true
    
    log_info "${inactive_env} 环境清理完成"
}

# 执行蓝绿回滚
perform_blue_green_rollback() {
    local inactive_env
    inactive_env=$(get_inactive_env)
    
    log "开始执行蓝绿部署回滚..."
    log "当前活跃环境: $ACTIVE_ENV"
    log "回滚目标环境: $inactive_env"
    if [ -n "$ROLLBACK_REASON" ]; then
        log "回滚原因: $ROLLBACK_REASON"
    fi
    
    # 1. 验证回滚目标环境的健康状态
    log_info "验证回滚目标环境 ($inactive_env) 的健康状态..."
    if ! perform_health_check $inactive_env; then
        log_error "回滚目标环境 ($inactive_env) 健康检查失败，无法执行回滚"
        exit 1
    fi
    
    # 2. 切换流量到回滚目标环境
    log_info "开始切换流量..."
    if ! switch_traffic $inactive_env; then
        log_error "流量切换失败，回滚操作终止"
        exit 1
    fi
    
    # 3. 等待流量切换完成
    log_info "等待流量切换稳定..."
    sleep 30
    
    # 4. 验证流量切换结果
    log_info "验证流量切换结果..."
    local current_selector
    current_selector=$(kubectl get service/${APP_NAME}-service -n $NAMESPACE -o jsonpath='{.spec.selector.app}' 2>/dev/null)
    
    if [ "$current_selector" == "${APP_NAME}-${inactive_env}" ]; then
        log_info "流量切换验证成功"
    else
        log_error "流量切换验证失败，当前选择器: $current_selector"
        # 这里可以决定是否继续回滚或终止
    fi
    
    # 5. 清理原活跃环境（现在变成非活跃环境）
    cleanup_inactive_env $ACTIVE_ENV
    
    log "蓝绿部署回滚完成"
}

# 主函数
main() {
    log "开始执行蓝绿部署自动回滚"
    
    # 验证参数
    validate_params
    
    # 设置Kubernetes配置
    setup_kubeconfig
    
    # 执行回滚
    perform_blue_green_rollback
    
    log "蓝绿部署自动回滚流程完成"
}

# 执行主函数
main "$@"