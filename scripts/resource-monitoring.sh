#!/bin/bash

# CI/CD资源监控脚本
# 用于监控CI/CD流程中的资源使用情况

set -euo pipefail

# 全局变量
METRICS_DIR="metrics"
START_TIME=$(date +%s)
JOB_NAME=${JOB_NAME:-"unknown-job"}
BUILD_NUMBER=${BUILD_NUMBER:-"unknown-build"}

# 函数：初始化监控
init_monitoring() {
  echo "初始化资源监控..."
  
  # 创建指标目录
  mkdir -p "$METRICS_DIR"
  
  # 记录开始时间
  echo "$START_TIME" > "$METRICS_DIR/start_time.txt"
  
  # 记录环境信息
  {
    echo "Job Name: $JOB_NAME"
    echo "Build Number: $BUILD_NUMBER"
    echo "Host: $(hostname)"
    echo "OS: $(uname -s)"
    echo "Architecture: $(uname -m)"
  } > "$METRICS_DIR/environment.txt"
  
  echo "资源监控初始化完成"
}

# 函数：监控CPU使用情况
monitor_cpu() {
  local interval=${1:-5}  # 默认5秒采样间隔
  local duration=${2:-60} # 默认监控60秒
  
  echo "监控CPU使用情况 (间隔: ${interval}s, 持续: ${duration}s)..."
  
  # 使用top命令收集CPU信息
  top -b -d "$interval" -n $((duration/interval)) > "$METRICS_DIR/cpu_usage.txt" &
  local top_pid=$!
  
  # 等待监控完成
  wait $top_pid
  
  # 计算平均CPU使用率
  local avg_cpu=$(grep "Cpu(s)" "$METRICS_DIR/cpu_usage.txt" | awk '{print $2}' | sed 's/%us,//' | awk '{sum+=$1} END {print sum/NR}')
  echo "Average CPU Usage: ${avg_cpu}%" > "$METRICS_DIR/cpu_summary.txt"
  
  echo "CPU监控完成"
}

# 函数：监控内存使用情况
monitor_memory() {
  echo "监控内存使用情况..."
  
  # 获取当前内存使用情况
  free -m > "$METRICS_DIR/memory_usage.txt"
  
  # 获取详细内存信息
  cat /proc/meminfo > "$METRICS_DIR/memory_info.txt"
  
  # 计算内存使用率
  local mem_total=$(grep "MemTotal" "$METRICS_DIR/memory_info.txt" | awk '{print $2}')
  local mem_free=$(grep "MemFree" "$METRICS_DIR/memory_info.txt" | awk '{print $2}')
  local mem_used=$((mem_total - mem_free))
  local mem_usage_percent=$(awk "BEGIN {printf \"%.2f\", $mem_used/$mem_total*100}")
  
  {
    echo "Memory Total: ${mem_total} kB"
    echo "Memory Used: ${mem_used} kB"
    echo "Memory Free: ${mem_free} kB"
    echo "Memory Usage: ${mem_usage_percent}%"
  } > "$METRICS_DIR/memory_summary.txt"
  
  echo "内存监控完成"
}

# 函数：监控磁盘使用情况
monitor_disk() {
  echo "监控磁盘使用情况..."
  
  # 获取磁盘使用情况
  df -h > "$METRICS_DIR/disk_usage.txt"
  
  # 获取当前目录磁盘使用情况
  du -sh . > "$METRICS_DIR/current_directory_size.txt"
  
  echo "磁盘监控完成"
}

# 函数：监控网络使用情况
monitor_network() {
  echo "监控网络使用情况..."
  
  # 获取网络接口信息
  ip addr show > "$METRICS_DIR/network_interfaces.txt"
  
  # 获取网络统计信息
  cat /proc/net/dev > "$METRICS_DIR/network_stats.txt"
  
  echo "网络监控完成"
}

# 函数：监控Docker资源使用情况
monitor_docker() {
  if command -v docker &> /dev/null; then
    echo "监控Docker资源使用情况..."
    
    # 获取Docker系统信息
    docker info > "$METRICS_DIR/docker_info.txt" 2>/dev/null || echo "无法获取Docker信息" > "$METRICS_DIR/docker_info.txt"
    
    # 获取运行中的容器
    docker ps > "$METRICS_DIR/docker_containers.txt" 2>/dev/null || echo "无法获取容器信息" > "$METRICS_DIR/docker_containers.txt"
    
    # 获取Docker磁盘使用情况
    docker system df -v > "$METRICS_DIR/docker_disk_usage.txt" 2>/dev/null || echo "无法获取Docker磁盘使用信息" > "$METRICS_DIR/docker_disk_usage.txt"
  else
    echo "Docker未安装，跳过Docker监控"
    echo "Docker not installed" > "$METRICS_DIR/docker_info.txt"
  fi
}

# 函数：监控进程资源使用情况
monitor_processes() {
  echo "监控进程资源使用情况..."
  
  # 获取当前进程列表
  ps aux --sort=-%cpu | head -20 > "$METRICS_DIR/top_cpu_processes.txt"
  ps aux --sort=-%mem | head -20 > "$METRICS_DIR/top_memory_processes.txt"
  
  # 获取进程树
  pstree -p > "$METRICS_DIR/process_tree.txt"
  
  echo "进程监控完成"
}

# 函数：收集自定义指标
collect_custom_metrics() {
  echo "收集自定义指标..."
  
  # 收集自定义指标（可根据需要扩展）
  {
    echo "Custom Metric 1: $(date)"
    echo "Custom Metric 2: Some value"
  } > "$METRICS_DIR/custom_metrics.txt"
  
  echo "自定义指标收集完成"
}

# 函数：生成监控报告
generate_report() {
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  
  echo "生成监控报告..."
  
  # 创建汇总报告
  {
    echo "# CI/CD资源使用监控报告"
    echo "生成时间: $(date)"
    echo "任务名称: $JOB_NAME"
    echo "构建编号: $BUILD_NUMBER"
    echo "执行时长: ${duration}秒 ($(printf "%.2f" $(echo "$duration/60" | bc -l))分钟)"
    echo ""
    echo "## 环境信息"
    cat "$METRICS_DIR/environment.txt"
    echo ""
    echo "## CPU使用情况"
    if [[ -f "$METRICS_DIR/cpu_summary.txt" ]]; then
      cat "$METRICS_DIR/cpu_summary.txt"
    else
      echo "未收集到CPU信息"
    fi
    echo ""
    echo "## 内存使用情况"
    if [[ -f "$METRICS_DIR/memory_summary.txt" ]]; then
      cat "$METRICS_DIR/memory_summary.txt"
    else
      echo "未收集到内存信息"
    fi
    echo ""
    echo "## 磁盘使用情况"
    if [[ -f "$METRICS_DIR/current_directory_size.txt" ]]; then
      echo "当前目录大小: $(cat "$METRICS_DIR/current_directory_size.txt")"
    fi
  } > "$METRICS_DIR/monitoring_report.md"
  
  echo "监控报告生成完成: $METRICS_DIR/monitoring_report.md"
}

# 函数：上传指标到监控系统
upload_metrics() {
  echo "上传指标到监控系统..."
  
  # 这里可以实现将指标上传到Prometheus、InfluxDB等监控系统
  # 示例伪代码：
  # curl -X POST -H "Content-Type: application/json" \
  #   -d @"$METRICS_DIR/metrics.json" \
  #   http://monitoring-server:9090/api/v1/write
  
  echo "指标上传完成（模拟）"
}

# 函数：清理监控数据
cleanup() {
  echo "清理监控数据..."
  
  # 可以选择保留或删除监控数据
  # rm -rf "$METRICS_DIR"
  
  echo "监控数据清理完成"
}

# 主函数
main() {
  local action=${1:-"all"}
  
  case $action in
    "init")
      init_monitoring
      ;;
    "cpu")
      monitor_cpu "${2:-5}" "${3:-60}"
      ;;
    "memory")
      monitor_memory
      ;;
    "disk")
      monitor_disk
      ;;
    "network")
      monitor_network
      ;;
    "docker")
      monitor_docker
      ;;
    "processes")
      monitor_processes
      ;;
    "custom")
      collect_custom_metrics
      ;;
    "report")
      generate_report
      ;;
    "upload")
      upload_metrics
      ;;
    "cleanup")
      cleanup
      ;;
    "all")
      init_monitoring
      monitor_cpu 5 30
      monitor_memory
      monitor_disk
      monitor_network
      monitor_docker
      monitor_processes
      collect_custom_metrics
      generate_report
      upload_metrics
      ;;
    *)
      echo "用法: $0 [init|cpu|memory|disk|network|docker|processes|custom|report|upload|cleanup|all]"
      exit 1
      ;;
  esac
}

# 如果脚本直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi