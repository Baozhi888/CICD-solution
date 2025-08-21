#!/bin/bash

# 性能基准测试脚本
# 用于在CI/CD流程中执行性能基准测试

set -euo pipefail

# 全局变量
BENCHMARK_DIR="benchmarks"
RESULTS_DIR="benchmark-results"
BASELINE_DIR="benchmark-baselines"

# 函数：初始化基准测试
init_benchmark() {
  echo "初始化性能基准测试..."
  
  # 创建必要的目录
  mkdir -p "$BENCHMARK_DIR" "$RESULTS_DIR" "$BASELINE_DIR"
  
  # 记录测试开始时间
  echo "$(date)" > "$RESULTS_DIR/start_time.txt"
  
  echo "基准测试初始化完成"
}

# 函数：执行Node.js性能测试
benchmark_nodejs() {
  echo "执行Node.js性能基准测试..."
  
  # 检查是否安装了benchmark工具
  if ! command -v npx &> /dev/null; then
    echo "未找到npm，请先安装Node.js"
    return 1
  fi
  
  # 创建简单的基准测试文件
  cat > "$BENCHMARK_DIR/nodejs-benchmark.js" << 'EOF'
const https = require('https');
const http = require('http');
const { spawn } = require('child_process');

// 简单的CPU密集型测试
function cpuIntensiveTest() {
  let result = 0;
  for (let i = 0; i < 1000000; i++) {
    result += Math.sqrt(i);
  }
  return result;
}

// 简单的内存分配测试
function memoryIntensiveTest() {
  const arr = new Array(1000000);
  for (let i = 0; i < arr.length; i++) {
    arr[i] = { id: i, data: `data-${i}` };
  }
  return arr.length;
}

// HTTP请求测试
function httpTest() {
  return new Promise((resolve, reject) => {
    const req = http.get('http://httpbin.org/get', (res) => {
      let data = '';
      res.on('data', (chunk) => {
        data += chunk;
      });
      res.on('end', () => {
        resolve(data.length);
      });
    });
    req.on('error', (err) => {
      reject(err);
    });
    req.end();
  });
}

// 运行基准测试
async function runBenchmarks() {
  const startTime = process.hrtime.bigint();
  
  // CPU测试
  const cpuResult = cpuIntensiveTest();
  const cpuTime = Number(process.hrtime.bigint() - startTime) / 1000000;
  
  // 内存测试
  const memResult = memoryIntensiveTest();
  const memTime = Number(process.hrtime.bigint() - startTime) / 1000000 - cpuTime;
  
  // HTTP测试
  let httpResult, httpTime;
  try {
    const httpStart = process.hrtime.bigint();
    httpResult = await httpTest();
    httpTime = Number(process.hrtime.bigint() - httpStart) / 1000000;
  } catch (err) {
    httpResult = 0;
    httpTime = 0;
  }
  
  return {
    cpu: { result: cpuResult, time: cpuTime },
    memory: { result: memResult, time: memTime },
    http: { result: httpResult, time: httpTime },
    total: Number(process.hrtime.bigint() - startTime) / 1000000
  };
}

// 执行测试
runBenchmarks().then(results => {
  console.log(JSON.stringify(results, null, 2));
}).catch(err => {
  console.error('Benchmark failed:', err);
  process.exit(1);
});
EOF
  
  # 执行基准测试
  echo "运行Node.js基准测试..."
  local start_time=$(date +%s%3N)
  node "$BENCHMARK_DIR/nodejs-benchmark.js" > "$RESULTS_DIR/nodejs-results.json"
  local end_time=$(date +%s%3N)
  local execution_time=$((end_time - start_time))
  
  # 添加执行时间到结果
  local temp_file=$(mktemp)
  jq --arg time "$execution_time" '.execution_time = $time' "$RESULTS_DIR/nodejs-results.json" > "$temp_file"
  mv "$temp_file" "$RESULTS_DIR/nodejs-results.json"
  
  echo "Node.js基准测试完成，耗时: ${execution_time}ms"
}

# 函数：执行Docker镜像构建性能测试
benchmark_docker_build() {
  echo "执行Docker镜像构建性能基准测试..."
  
  # 检查Docker是否可用
  if ! command -v docker &> /dev/null; then
    echo "未找到Docker，请先安装Docker"
    return 1
  fi
  
  # 创建简单的Dockerfile用于测试
  cat > "$BENCHMARK_DIR/Dockerfile.benchmark" << 'EOF'
FROM alpine:latest
RUN apk add --no-cache curl
COPY . /app
WORKDIR /app
RUN echo "Benchmark test" > README.md
EOF
  
  # 创建测试文件
  echo "Docker build benchmark test" > "$BENCHMARK_DIR/test-file.txt"
  
  # 执行Docker构建测试
  local start_time=$(date +%s%3N)
  docker build -f "$BENCHMARK_DIR/Dockerfile.benchmark" -t benchmark-test "$BENCHMARK_DIR" > "$RESULTS_DIR/docker-build.log" 2>&1
  local end_time=$(date +%s%3N)
  local build_time=$((end_time - start_time))
  
  # 记录构建时间
  echo "{ \"build_time_ms\": $build_time }" > "$RESULTS_DIR/docker-build-results.json"
  
  # 清理测试镜像
  docker rmi benchmark-test 2>/dev/null || true
  
  echo "Docker构建基准测试完成，耗时: ${build_time}ms"
}

# 函数：执行测试套件性能测试
benchmark_test_suites() {
  echo "执行测试套件性能基准测试..."
  
  # 检查是否存在测试配置
  if [[ ! -f "package.json" ]]; then
    echo "未找到package.json，跳过测试套件基准测试"
    return 0
  fi
  
  # 检查是否有测试脚本
  if ! jq -e '.scripts | has("test")' package.json > /dev/null; then
    echo "package.json中未定义test脚本，跳过测试套件基准测试"
    return 0
  fi
  
  # 执行测试并测量时间
  local start_time=$(date +%s%3N)
  
  # 执行测试（限制执行时间）
  timeout 300 npm test > "$RESULTS_DIR/test-suite-output.log" 2>&1 || {
    echo "测试套件执行超时或失败"
    local end_time=$(date +%s%3N)
    local test_time=$((end_time - start_time))
    echo "{ \"test_time_ms\": $test_time, \"status\": \"timeout_or_failed\" }" > "$RESULTS_DIR/test-suite-results.json"
    return 0
  }
  
  local end_time=$(date +%s%3N)
  local test_time=$((end_time - start_time))
  
  # 记录测试结果
  echo "{ \"test_time_ms\": $test_time, \"status\": \"completed\" }" > "$RESULTS_DIR/test-suite-results.json"
  
  echo "测试套件基准测试完成，耗时: ${test_time}ms"
}

# 函数：比较基准测试结果
compare_benchmarks() {
  echo "比较基准测试结果..."
  
  # 检查是否存在基线数据
  if [[ ! -d "$BASELINE_DIR" ]] || [[ -z "$(ls -A "$BASELINE_DIR")" ]]; then
    echo "未找到基线数据，将当前结果作为基线保存"
    cp -r "$RESULTS_DIR"/* "$BASELINE_DIR"/ 2>/dev/null || echo "无法保存基线数据"
    echo "{ \"status\": \"baseline_created\" }" > "$RESULTS_DIR/comparison-results.json"
    return 0
  fi
  
  # 比较结果
  local comparison_result="{ \"comparisons\": [] }"
  
  # 比较Node.js基准测试结果
  if [[ -f "$RESULTS_DIR/nodejs-results.json" ]] && [[ -f "$BASELINE_DIR/nodejs-results.json" ]]; then
    local current_total=$(jq '.total' "$RESULTS_DIR/nodejs-results.json")
    local baseline_total=$(jq '.total' "$BASELINE_DIR/nodejs-results.json")
    local diff_percent=$(awk "BEGIN {printf \"%.2f\", (($current_total - $baseline_total) / $baseline_total) * 100}")
    
    local nodejs_comparison="{ \"test\": \"nodejs\", \"current\": $current_total, \"baseline\": $baseline_total, \"diff_percent\": $diff_percent }"
    comparison_result=$(echo "$comparison_result" | jq ".comparisons += [$nodejs_comparison]")
  fi
  
  # 比较Docker构建时间
  if [[ -f "$RESULTS_DIR/docker-build-results.json" ]] && [[ -f "$BASELINE_DIR/docker-build-results.json" ]]; then
    local current_build_time=$(jq '.build_time_ms' "$RESULTS_DIR/docker-build-results.json")
    local baseline_build_time=$(jq '.build_time_ms' "$BASELINE_DIR/docker-build-results.json")
    local diff_percent=$(awk "BEGIN {printf \"%.2f\", (($current_build_time - $baseline_build_time) / $baseline_build_time) * 100}")
    
    local docker_comparison="{ \"test\": \"docker_build\", \"current\": $current_build_time, \"baseline\": $baseline_build_time, \"diff_percent\": $diff_percent }"
    comparison_result=$(echo "$comparison_result" | jq ".comparisons += [$docker_comparison]")
  fi
  
  # 比较测试套件执行时间
  if [[ -f "$RESULTS_DIR/test-suite-results.json" ]] && [[ -f "$BASELINE_DIR/test-suite-results.json" ]]; then
    local current_test_time=$(jq '.test_time_ms' "$RESULTS_DIR/test-suite-results.json")
    local baseline_test_time=$(jq '.test_time_ms' "$BASELINE_DIR/test-suite-results.json")
    local diff_percent=$(awk "BEGIN {printf \"%.2f\", (($current_test_time - $baseline_test_time) / $baseline_test_time) * 100}")
    
    local test_comparison="{ \"test\": \"test_suite\", \"current\": $current_test_time, \"baseline\": $baseline_test_time, \"diff_percent\": $diff_percent }"
    comparison_result=$(echo "$comparison_result" | jq ".comparisons += [$test_comparison]")
  fi
  
  echo "$comparison_result" > "$RESULTS_DIR/comparison-results.json"
  
  # 检查是否有显著性能下降
  local performance_degradation=false
  echo "$comparison_result" | jq -c '.comparisons[]' | while read -r comparison; do
    local diff_percent=$(echo "$comparison" | jq '.diff_percent')
    if (( $(echo "$diff_percent > 10" | bc -l) )); then
      local test_name=$(echo "$comparison" | jq -r '.test')
      echo "警告: $test_name 性能下降 ${diff_percent}%"
      performance_degradation=true
    fi
  done
  
  if [[ "$performance_degradation" == "true" ]]; then
    echo "{ \"status\": \"performance_degradation_detected\" }" > "$RESULTS_DIR/comparison-summary.json"
  else
    echo "{ \"status\": \"performance_stable\" }" > "$RESULTS_DIR/comparison-summary.json"
  fi
  
  echo "基准测试结果比较完成"
}

# 函数：生成基准测试报告
generate_benchmark_report() {
  echo "生成基准测试报告..."
  
  # 创建详细的基准测试报告
  {
    echo "# 性能基准测试报告"
    echo "生成时间: $(date)"
    echo ""
    
    # Node.js基准测试结果
    echo "## Node.js基准测试结果"
    if [[ -f "$RESULTS_DIR/nodejs-results.json" ]]; then
      echo '```json'
      cat "$RESULTS_DIR/nodejs-results.json" | jq '.'
      echo '```'
    else
      echo "未执行Node.js基准测试"
    fi
    echo ""
    
    # Docker构建性能结果
    echo "## Docker构建性能结果"
    if [[ -f "$RESULTS_DIR/docker-build-results.json" ]]; then
      echo '```json'
      cat "$RESULTS_DIR/docker-build-results.json" | jq '.'
      echo '```'
    else
      echo "未执行Docker构建基准测试"
    fi
    echo ""
    
    # 测试套件性能结果
    echo "## 测试套件性能结果"
    if [[ -f "$RESULTS_DIR/test-suite-results.json" ]]; then
      echo '```json'
      cat "$RESULTS_DIR/test-suite-results.json" | jq '.'
      echo '```'
    else
      echo "未执行测试套件基准测试"
    fi
    echo ""
    
    # 比较结果
    echo "## 基准测试比较结果"
    if [[ -f "$RESULTS_DIR/comparison-results.json" ]]; then
      echo '```json'
      cat "$RESULTS_DIR/comparison-results.json" | jq '.'
      echo '```'
    else
      echo "未执行基准测试比较"
    fi
    echo ""
    
    # 比较摘要
    echo "## 比较摘要"
    if [[ -f "$RESULTS_DIR/comparison-summary.json" ]]; then
      echo '```json'
      cat "$RESULTS_DIR/comparison-summary.json" | jq '.'
      echo '```'
    else
      echo "无比较摘要"
    fi
  } > "$RESULTS_DIR/benchmark-report.md"
  
  echo "基准测试报告生成完成: $RESULTS_DIR/benchmark-report.md"
}

# 函数：保存当前结果作为基线
save_baseline() {
  echo "保存当前结果作为基线..."
  
  # 清空基线目录
  rm -rf "$BASELINE_DIR"/*
  
  # 复制当前结果作为基线
  cp -r "$RESULTS_DIR"/* "$BASELINE_DIR"/ 2>/dev/null || echo "无法保存基线数据"
  
  echo "基线数据保存完成"
}

# 主函数
main() {
  local action=${1:-"all"}
  
  case $action in
    "init")
      init_benchmark
      ;;
    "nodejs")
      benchmark_nodejs
      ;;
    "docker")
      benchmark_docker_build
      ;;
    "tests")
      benchmark_test_suites
      ;;
    "compare")
      compare_benchmarks
      ;;
    "report")
      generate_benchmark_report
      ;;
    "baseline")
      save_baseline
      ;;
    "all")
      init_benchmark
      benchmark_nodejs
      benchmark_docker_build
      benchmark_test_suites
      compare_benchmarks
      generate_benchmark_report
      ;;
    *)
      echo "用法: $0 [init|nodejs|docker|tests|compare|report|baseline|all]"
      exit 1
      ;;
  esac
}

# 如果脚本直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi