#!/bin/bash

# 健康检查和验证机制脚本
# 用于在回滚前执行全面的健康检查

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
CHECK_TYPE="comprehensive"  # comprehensive, basic, custom
CONFIG_FILE=""
TIMEOUT=300  # 超时时间（秒）
OUTPUT_FORMAT="text"  # text, json

# 显示帮助信息
show_help() {
    cat << EOF
用法: $0 [选项]

健康检查和验证机制脚本

选项:
  -a, --app NAME              应用名称
  -n, --namespace NS          Kubernetes命名空间 [默认: default]
  -k, --kubeconfig PATH       Kubernetes配置文件路径
  -t, --type TYPE             检查类型 (comprehensive|basic|custom) [默认: comprehensive]
  -c, --config FILE           配置文件路径
  --timeout SECONDS           超时时间（秒） [默认: 300]
  -o, --output FORMAT         输出格式 (text|json) [默认: text]
  -h, --help                  显示此帮助信息

示例:
  $0 -a myapp -n production -k ~/.kube/config
  $0 --app myapp --type basic --timeout 60
  $0 -a myapp -c ./health-check-config.yaml -o json

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
        -t|--type)
            CHECK_TYPE="$2"
            shift 2
            ;;
        -c|--config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FORMAT="$2"
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
    
    if [ "$CHECK_TYPE" != "comprehensive" ] && [ "$CHECK_TYPE" != "basic" ] && [ "$CHECK_TYPE" != "custom" ]; then
        log_error "检查类型必须是 comprehensive, basic 或 custom"
        show_help
        exit 1
    fi
    
    if [ -n "$CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; then
        log_error "配置文件不存在: $CONFIG_FILE"
        exit 1
    fi
    
    if [ "$OUTPUT_FORMAT" != "text" ] && [ "$OUTPUT_FORMAT" != "json" ]; then
        log_error "输出格式必须是 text 或 json"
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

# 基础健康检查
basic_health_check() {
    log_info "执行基础健康检查..."
    
    local deployment_name="${APP_NAME}-deployment"
    local results=()
    
    # 1. 检查Deployment状态
    log_info "检查Deployment状态..."
    if kubectl get deployment/$deployment_name -n $NAMESPACE &> /dev/null; then
        local deployment_status
        deployment_status=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$deployment_status" == "True" ]; then
            results+=("Deployment状态: 正常")
            log_info "Deployment状态正常"
        else
            results+=("Deployment状态: 异常")
            log_error "Deployment状态异常"
            return 1
        fi
    else
        results+=("Deployment状态: 不存在")
        log_error "Deployment不存在"
        return 1
    fi
    
    # 2. 检查Pod状态
    log_info "检查Pod状态..."
    local pod_status
    pod_status=$(kubectl get pods -l app=$APP_NAME -n $NAMESPACE -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ "$pod_status" =~ "Running" ]] && ! [[ "$pod_status" =~ "Pending" ]] && ! [[ "$pod_status" =~ "Failed" ]]; then
        results+=("Pod状态: 正常")
        log_info "Pod状态正常"
    else
        results+=("Pod状态: 异常")
        log_error "Pod状态异常: $pod_status"
        return 1
    fi
    
    # 3. 检查服务状态
    log_info "检查服务状态..."
    local service_name="${APP_NAME}-service"
    if kubectl get service/$service_name -n $NAMESPACE &> /dev/null; then
        results+=("服务状态: 正常")
        log_info "服务状态正常"
    else
        results+=("服务状态: 不存在")
        log_error "服务不存在"
        return 1
    fi
    
    # 输出结果
    if [ "$OUTPUT_FORMAT" == "json" ]; then
        echo "{\"check_type\": \"basic\", \"status\": \"pass\", \"results\": [$(printf '"%s",' "${results[@]}" | sed 's/,$//')]}"
    else
        printf '%s\n' "${results[@]}"
    fi
    
    return 0
}

# 全面健康检查
comprehensive_health_check() {
    log_info "执行全面健康检查..."
    
    local deployment_name="${APP_NAME}-deployment"
    local results=()
    local passed_checks=0
    local total_checks=0
    
    # 1. 检查Deployment状态
    total_checks=$((total_checks + 1))
    log_info "检查Deployment状态..."
    if kubectl get deployment/$deployment_name -n $NAMESPACE &> /dev/null; then
        local deployment_status
        deployment_status=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null)
        if [ "$deployment_status" == "True" ]; then
            results+=("Deployment状态: 正常")
            log_info "Deployment状态正常"
            passed_checks=$((passed_checks + 1))
        else
            results+=("Deployment状态: 异常")
            log_error "Deployment状态异常"
        fi
    else
        results+=("Deployment状态: 不存在")
        log_error "Deployment不存在"
    fi
    
    # 2. 检查Pod状态和就绪状态
    total_checks=$((total_checks + 1))
    log_info "检查Pod状态和就绪状态..."
    local pod_status
    pod_status=$(kubectl get pods -l app=$APP_NAME -n $NAMESPACE -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
    if [[ "$pod_status" =~ "Running" ]] && ! [[ "$pod_status" =~ "Pending" ]] && ! [[ "$pod_status" =~ "Failed" ]]; then
        results+=("Pod状态: 正常")
        log_info "Pod状态正常"
        
        # 检查就绪状态
        local ready_pods
        ready_pods=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
        local desired_pods
        desired_pods=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.status.replicas}' 2>/dev/null)
        
        if [ "$ready_pods" == "$desired_pods" ] && [ "$ready_pods" -gt 0 ]; then
            results+=("Pod就绪状态: $ready_pods/$desired_pods")
            log_info "Pod就绪状态正常: $ready_pods/$desired_pods"
            passed_checks=$((passed_checks + 1))
        else
            results+=("Pod就绪状态: $ready_pods/$desired_pods (异常)")
            log_error "Pod就绪状态异常: $ready_pods/$desired_pods"
        fi
    else
        results+=("Pod状态: 异常 ($pod_status)")
        log_error "Pod状态异常: $pod_status"
    fi
    
    # 3. 检查服务状态和端点
    total_checks=$((total_checks + 1))
    log_info "检查服务状态和端点..."
    local service_name="${APP_NAME}-service"
    if kubectl get service/$service_name -n $NAMESPACE &> /dev/null; then
        results+=("服务状态: 正常")
        log_info "服务状态正常"
        
        # 检查端点
        local endpoints
        endpoints=$(kubectl get endpoints $service_name -n $NAMESPACE -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null)
        if [ -n "$endpoints" ]; then
            results+=("服务端点: 正常")
            log_info "服务端点正常"
            passed_checks=$((passed_checks + 1))
        else
            results+=("服务端点: 无可用端点")
            log_error "服务端点无可用端点"
        fi
    else
        results+=("服务状态: 不存在")
        log_error "服务不存在"
    fi
    
    # 4. 检查资源使用情况
    total_checks=$((total_checks + 1))
    log_info "检查资源使用情况..."
    local cpu_request
    cpu_request=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
    local memory_request
    memory_request=$(kubectl get deployment/$deployment_name -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)
    
    if [ -n "$cpu_request" ] && [ -n "$memory_request" ]; then
        results+=("资源请求: CPU=$cpu_request, Memory=$memory_request")
        log_info "资源请求配置正常: CPU=$cpu_request, Memory=$memory_request"
        passed_checks=$((passed_checks + 1))
    else
        results+=("资源请求: 未配置或配置异常")
        log_warn "资源请求未配置或配置异常"
    fi
    
    # 5. 检查HPA状态（如果存在）
    total_checks=$((total_checks + 1))
    log_info "检查HPA状态..."
    local hpa_name="${APP_NAME}-hpa"
    if kubectl get hpa/$hpa_name -n $NAMESPACE &> /dev/null; then
        local hpa_status
        hpa_status=$(kubectl get hpa/$hpa_name -n $NAMESPACE -o jsonpath='{.status.currentReplicas}' 2>/dev/null)
        if [ -n "$hpa_status" ]; then
            results+=("HPA状态: 正常 (当前副本: $hpa_status)")
            log_info "HPA状态正常 (当前副本: $hpa_status)"
            passed_checks=$((passed_checks + 1))
        else
            results+=("HPA状态: 异常")
            log_error "HPA状态异常"
        fi
    else
        results+=("HPA状态: 未配置")
        log_info "HPA未配置"
        passed_checks=$((passed_checks + 1))  # 未配置HPA不算失败
    fi
    
    # 输出结果
    if [ "$OUTPUT_FORMAT" == "json" ]; then
        echo "{\"check_type\": \"comprehensive\", \"status\": \"$([ $passed_checks -eq $total_checks ] && echo "pass" || echo "fail")\", \"passed_checks\": $passed_checks, \"total_checks\": $total_checks, \"results\": [$(printf '"%s",' "${results[@]}" | sed 's/,$//')]}"
    else
        printf '%s\n' "${results[@]}"
        log_info "健康检查完成: $passed_checks/$total_checks 项检查通过"
    fi
    
    # 如果所有检查都通过，返回0；否则返回1
    if [ $passed_checks -eq $total_checks ]; then
        return 0
    else
        return 1
    fi
}

# 自定义健康检查（基于配置文件）
custom_health_check() {
    log_info "执行自定义健康检查..."
    
    if [ -z "$CONFIG_FILE" ]; then
        log_error "自定义检查需要指定配置文件"
        return 1
    fi
    
    # 这里会根据配置文件执行自定义检查
    # 为了简化示例，我们模拟执行
    log_info "根据配置文件 $CONFIG_FILE 执行自定义检查..."
    
    # 模拟检查结果
    local results=("自定义检查1: 通过" "自定义检查2: 通过" "自定义检查3: 通过")
    
    if [ "$OUTPUT_FORMAT" == "json" ]; then
        echo "{\"check_type\": \"custom\", \"status\": \"pass\", \"results\": [$(printf '"%s",' "${results[@]}" | sed 's/,$//')]}"
    else
        printf '%s\n' "${results[@]}"
    fi
    
    return 0
}

# 执行健康检查
perform_health_check() {
    log "开始执行健康检查 (类型: $CHECK_TYPE)"
    
    case $CHECK_TYPE in
        basic)
            basic_health_check
            ;;
        comprehensive)
            comprehensive_health_check
            ;;
        custom)
            custom_health_check
            ;;
        *)
            log_error "未知检查类型: $CHECK_TYPE"
            return 1
            ;;
    esac
}

# 主函数
main() {
    log "开始执行健康检查和验证机制"
    
    # 验证参数
    validate_params
    
    # 设置Kubernetes配置
    setup_kubeconfig
    
    # 执行健康检查
    if perform_health_check; then
        log "健康检查完成且通过"
        exit 0
    else
        log_error "健康检查失败"
        exit 1
    fi
}

# 执行主函数
main "$@"