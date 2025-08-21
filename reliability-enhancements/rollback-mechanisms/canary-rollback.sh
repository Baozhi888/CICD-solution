#!/bin/bash

# 金丝雀部署自动回滚脚本
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
KUBECONFIG=""
HEALTH_CHECK_TIMEOUT=300  # 健康检查超时时间（秒）
CANARY_THRESHOLD_CPU=80    # CPU使用率阈值（百分比）
CANARY_THRESHOLD_MEMORY=80 # 内存使用率阈值（百分比）
CANARY_THRESHOLD_ERROR_RATE=5  # 错误率阈值（百分比）
CANARY_THRESHOLD_LATENCY=1000  # 延迟阈值（毫秒）
CANARY_REPLICAS=1          # 金丝雀副本数
ROLLBACK_REASON=""

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

金丝雀部署自动回滚脚本

选项:
  -a, --app NAME              应用名称
  -n, --namespace NS          Kubernetes命名空间 [默认: default]
  -k, --kubeconfig PATH       Kubernetes配置文件路径
  -t, --timeout SECONDS       健康检查超时时间（秒） [默认: 300]
  --cpu-threshold PERCENT     CPU使用率阈值（百分比） [默认: 80]
  --memory-threshold PERCENT  内存使用率阈值（百分比） [默认: 80]
  --error-threshold PERCENT   错误率阈值（百分比） [默认: 5]
  --latency-threshold MS      延迟阈值（毫秒） [默认: 1000]
  --canary-replicas NUM       金丝雀副本数 [默认: 1]
  -r, --reason REASON         回滚原因
  -h, --help                  显示此帮助信息

示例:
  $0 -a myapp -n production -k ~/.kube/config
  $0 --app myapp --namespace staging --cpu-threshold 75 --memory-threshold 75

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
        -k|--kubeconfig)
            KUBECONFIG="$2"
            shift 2
            ;;
        -t|--timeout)
            HEALTH_CHECK_TIMEOUT="$2"
            shift 2
            ;;
        --cpu-threshold)
            CANARY_THRESHOLD_CPU="$2"
            shift 2
            ;;
        --memory-threshold)
            CANARY_THRESHOLD_MEMORY="$2"
            shift 2
            ;;
        --error-threshold)
            CANARY_THRESHOLD_ERROR_RATE="$2"
            shift 2
            ;;
        --latency-threshold)
            CANARY_THRESHOLD_LATENCY="$2"
            shift 2
            ;;
        --canary-replicas)
            CANARY_REPLICAS="$2"
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
    
    if [ -n "$KUBECONFIG" ] && [ ! -f "$KUBECONFIG" ]; then
        log_error "Kubernetes配置文件不存在: $KUBECONFIG"
        exit 1
    fi
    
    # 验证阈值参数
    if ! [[ "$CANARY_THRESHOLD_CPU" =~ ^[0-9]+$ ]] || [ "$CANARY_THRESHOLD_CPU" -lt 0 ] || [ "$CANARY_THRESHOLD_CPU" -gt 100 ]; then
        log_error "CPU阈值必须是0-100之间的整数"
        exit 1
    fi
    
    if ! [[ "$CANARY_THRESHOLD_MEMORY" =~ ^[0-9]+$ ]] || [ "$CANARY_THRESHOLD_MEMORY" -lt 0 ] || [ "$CANARY_THRESHOLD_MEMORY" -gt 100 ]; then
        log_error "内存阈值必须是0-100之间的整数"
        exit 1
    fi
    
    if ! [[ "$CANARY_THRESHOLD_ERROR_RATE" =~ ^[0-9]+$ ]] || [ "$CANARY_THRESHOLD_ERROR_RATE" -lt 0 ] || [ "$CANARY_THRESHOLD_ERROR_RATE" -gt 100 ]; then
        log_error "错误率阈值必须是0-100之间的整数"
        exit 1
    fi
    
    if ! [[ "$CANARY_THRESHOLD_LATENCY" =~ ^[0-9]+$ ]] || [ "$CANARY_THRESHOLD_LATENCY" -lt 0 ]; then
        log_error "延迟阈值必须是非负整数"
        exit 1
    fi
    
    if ! [[ "$CANARY_REPLICAS" =~ ^[0-9]+$ ]] || [ "$CANARY_REPLICAS" -lt 1 ]; then
        log_error "金丝雀副本数必须是正整数"
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

# 执行健康检查
perform_health_check() {
    local deployment_name="${APP_NAME}-canary"
    
    log_info "开始对金丝雀环境进行健康检查..."
    
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
    
    # 4. 执行应用特定的健康检查（如果定义了）
    log_info "执行应用特定健康检查..."
    if ! perform_app_health_check; then
        log_error "应用特定健康检查失败"
        return 1
    fi
    
    log_info "金丝雀环境健康检查通过"
    return 0
}

# 应用特定健康检查（可扩展）
perform_app_health_check() {
    local deployment_name="${APP_NAME}-canary"
    
    # 这里可以添加应用特定的健康检查逻辑
    # 例如：HTTP健康端点检查、数据库连接检查等
    
    # 模拟健康检查延迟
    sleep 5
    
    # 假设健康检查通过
    return 0
}

# 收集和分析指标
analyze_metrics() {
    local deployment_name="${APP_NAME}-canary"
    
    log_info "开始收集和分析金丝雀环境指标..."
    
    # 1. 收集CPU使用率
    local cpu_usage
    cpu_usage=$(get_cpu_usage $deployment_name)
    log_info "CPU使用率: ${cpu_usage}%"
    if [ "$(echo "$cpu_usage > $CANARY_THRESHOLD_CPU" | bc -l)" -eq 1 ]; then
        log_error "CPU使用率超过阈值 (${CANARY_THRESHOLD_CPU}%)"
        return 1
    fi
    
    # 2. 收集内存使用率
    local memory_usage
    memory_usage=$(get_memory_usage $deployment_name)
    log_info "内存使用率: ${memory_usage}%"
    if [ "$(echo "$memory_usage > $CANARY_THRESHOLD_MEMORY" | bc -l)" -eq 1 ]; then
        log_error "内存使用率超过阈值 (${CANARY_THRESHOLD_MEMORY}%)"
        return 1
    fi
    
    # 3. 检查错误率（模拟）
    local error_rate
    error_rate=$(get_error_rate $deployment_name)
    log_info "错误率: ${error_rate}%"
    if [ "$(echo "$error_rate > $CANARY_THRESHOLD_ERROR_RATE" | bc -l)" -eq 1 ]; then
        log_error "错误率超过阈值 (${CANARY_THRESHOLD_ERROR_RATE}%)"
        return 1
    fi
    
    # 4. 检查延迟（模拟）
    local latency
    latency=$(get_latency $deployment_name)
    log_info "平均延迟: ${latency}ms"
    if [ "$(echo "$latency > $CANARY_THRESHOLD_LATENCY" | bc -l)" -eq 1 ]; then
        log_error "延迟超过阈值 (${CANARY_THRESHOLD_LATENCY}ms)"
        return 1
    fi
    
    log_info "所有指标均在正常范围内"
    return 0
}

# 获取CPU使用率（模拟实现）
get_cpu_usage() {
    local deployment_name=$1
    # 在实际环境中，这里会从监控系统（如Prometheus）获取真实数据
    # 模拟返回一个随机值（0-100）
    echo $((RANDOM % 101))
}

# 获取内存使用率（模拟实现）
get_memory_usage() {
    local deployment_name=$1
    # 在实际环境中，这里会从监控系统（如Prometheus）获取真实数据
    # 模拟返回一个随机值（0-100）
    echo $((RANDOM % 101))
}

# 获取错误率（模拟实现）
get_error_rate() {
    local deployment_name=$1
    # 在实际环境中，这里会从监控系统（如Prometheus）获取真实数据
    # 模拟返回一个随机值（0-10）
    echo $((RANDOM % 11))
}

# 获取延迟（模拟实现）
get_latency() {
    local deployment_name=$1
    # 在实际环境中，这里会从监控系统（如Prometheus）获取真实数据
    # 模拟返回一个随机值（0-2000ms）
    echo $((RANDOM % 2001))
}

# 清理金丝雀环境
cleanup_canary_env() {
    local deployment_name="${APP_NAME}-canary"
    local service_name="${APP_NAME}-canary"
    
    log_info "清理金丝雀环境..."
    
    # 删除Deployment
    kubectl delete deployment/$deployment_name -n $NAMESPACE --ignore-not-found=true
    
    # 删除Service
    kubectl delete service/$service_name -n $NAMESPACE --ignore-not-found=true
    
    # 如果使用了HorizontalPodAutoscaler，也需要删除
    kubectl delete hpa/$deployment_name -n $NAMESPACE --ignore-not-found=true
    
    log_info "金丝雀环境清理完成"
}

# 执行金丝雀回滚
perform_canary_rollback() {
    log "开始执行金丝雀部署回滚..."
    if [ -n "$ROLLBACK_REASON" ]; then
        log "回滚原因: $ROLLBACK_REASON"
    fi
    
    # 1. 验证主环境的健康状态
    log_info "验证主环境的健康状态..."
    local main_deployment_name="${APP_NAME}-main"
    
    # 检查主Deployment是否存在
    if ! kubectl get deployment/$main_deployment_name -n $NAMESPACE &> /dev/null; then
        log_warn "主环境Deployment不存在，可能需要手动恢复"
        # 这里可以根据需要决定是否终止回滚
    else
        # 检查主Deployment状态
        if ! kubectl rollout status deployment/$main_deployment_name -n $NAMESPACE --timeout=60s; then
            log_warn "主环境Deployment状态异常，但继续执行回滚"
        fi
    fi
    
    # 2. 清理金丝雀环境
    cleanup_canary_env
    
    # 3. 重置流量路由（如果使用了服务网格或Ingress）
    reset_traffic_routing
    
    log "金丝雀部署回滚完成"
}

# 重置流量路由
reset_traffic_routing() {
    local service_name="${APP_NAME}-service"
    
    log_info "重置流量路由..."
    
    # 这里需要根据实际的流量管理方案来实现
    # 例如：更新Ingress规则、服务网格配置等
    
    # 示例：更新服务选择器回到主环境
    if kubectl patch service/$service_name -n $NAMESPACE -p "{\"spec\":{\"selector\":{\"app\":\"${APP_NAME}-main\"}}}"; then
        log_info "流量路由已重置到主环境"
    else
        log_warn "流量路由重置失败"
    fi
}

# 主函数
main() {
    log "开始执行金丝雀部署自动回滚"
    
    # 验证参数
    validate_params
    
    # 设置Kubernetes配置
    setup_kubeconfig
    
    # 执行回滚
    perform_canary_rollback
    
    log "金丝雀部署自动回滚流程完成"
}

# 执行主函数
main "$@"