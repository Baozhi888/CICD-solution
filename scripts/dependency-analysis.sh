#!/bin/bash

# 依赖分析和优化脚本
# 用于分析项目依赖并优化CI/CD执行顺序

set -euo pipefail

# 函数：分析Node.js依赖
analyze_nodejs_dependencies() {
  echo "分析Node.js依赖..."
  
  # 生成依赖树
  npm ls --all --json > dependency-tree.json
  
  # 分析生产依赖和开发依赖
  local prod_deps=$(npm ls --prod --depth=0 | grep -E "^[├└]─" | wc -l)
  local dev_deps=$(npm ls --dev --depth=0 | grep -E "^[├└]─" | wc -l)
  
  echo "生产依赖数量: $prod_deps"
  echo "开发依赖数量: $dev_deps"
  
  # 识别关键依赖（被多个包依赖的）
  echo "识别关键依赖..."
  jq -r '.dependencies | keys[]' dependency-tree.json | head -10
  
  # 识别大型依赖
  echo "分析依赖大小..."
  npm ls --prod --depth=0 --json | jq -r '.dependencies | to_entries[] | "\(.key)@\(.value.version)"' > prod-deps.txt
  
  echo "依赖分析完成"
}

# 函数：分析Python依赖
analyze_python_dependencies() {
  echo "分析Python依赖..."
  
  if [[ ! -f "requirements.txt" ]]; then
    echo "未找到requirements.txt文件"
    return 0
  fi
  
  # 生成依赖树
  pipdeptree > dependency-tree-python.txt
  
  # 分析依赖数量
  local dep_count=$(wc -l < requirements.txt)
  echo "Python依赖数量: $dep_count"
  
  echo "Python依赖分析完成"
}

# 函数：优化任务执行顺序
optimize_task_order() {
  echo "优化任务执行顺序..."
  
  # 根据依赖分析结果，确定最优执行顺序
  # 1. 先执行代码质量检查（不需要安装依赖）
  # 2. 并行执行依赖安装和安全扫描
  # 3. 根据依赖重要性执行测试
  
  cat > task-execution-order.txt << EOF
推荐的任务执行顺序：
1. 代码质量检查 (format, lint) - 不依赖安装
2. 依赖安装 (npm ci) - 并行执行
3. 安全扫描 (npm audit) - 依赖安装完成后执行
4. 单元测试 - 根据依赖重要性排序
5. 集成测试 - 需要完整环境
6. 端到端测试 - 最后执行
EOF
  
  echo "任务执行顺序优化完成"
}

# 函数：生成依赖报告
generate_dependency_report() {
  echo "生成依赖报告..."
  
  mkdir -p dependency-reports
  
  # 生成Node.js依赖报告
  if [[ -f "package.json" ]]; then
    {
      echo "# Node.js 依赖报告"
      echo "生成时间: $(date)"
      echo ""
      echo "## 依赖统计"
      npm ls --depth=0 | grep -E "^[├└]─" | wc -l | xargs echo "总依赖数: "
      npm ls --prod --depth=0 | grep -E "^[├└]─" | wc -l | xargs echo "生产依赖数: "
      npm ls --dev --depth=0 | grep -E "^[├└]─" | wc -l | xargs echo "开发依赖数: "
      echo ""
      echo "## 依赖树"
      npm ls --depth=2
    } > dependency-reports/nodejs-report.md
  fi
  
  # 生成Python依赖报告
  if [[ -f "requirements.txt" ]]; then
    {
      echo "# Python 依赖报告"
      echo "生成时间: $(date)"
      echo ""
      echo "## 依赖统计"
      wc -l < requirements.txt | xargs echo "总依赖数: "
      echo ""
      echo "## 依赖树"
      pipdeptree
    } > dependency-reports/python-report.md
  fi
  
  echo "依赖报告生成完成"
}

# 函数：识别关键路径
identify_critical_path() {
  echo "识别关键路径..."
  
  # 根据依赖分析，识别CI/CD流程中的关键路径
  cat > critical-path-analysis.txt << EOF
关键路径分析:
1. 代码质量检查: 快速反馈，应优先执行
2. 安全扫描: 高优先级，但可并行
3. 单元测试: 核心验证，可并行执行
4. 集成测试: 依赖外部服务，中等优先级
5. 端到端测试: 最耗时，最后执行
EOF
  
  echo "关键路径识别完成"
}

# 主函数
main() {
  echo "开始依赖分析和任务优化..."
  
  # 分析Node.js依赖
  if [[ -f "package.json" ]]; then
    analyze_nodejs_dependencies
  fi
  
  # 分析Python依赖
  if [[ -f "requirements.txt" ]]; then
    analyze_python_dependencies
  fi
  
  # 优化任务执行顺序
  optimize_task_order
  
  # 生成依赖报告
  generate_dependency_report
  
  # 识别关键路径
  identify_critical_path
  
  echo "依赖分析和任务优化完成"
}

# 如果脚本直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi