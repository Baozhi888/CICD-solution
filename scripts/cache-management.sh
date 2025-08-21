#!/bin/bash

# 缓存管理脚本
# 用于优化CI/CD流程中的缓存策略

set -euo pipefail

# 函数：清理npm缓存
clean_npm_cache() {
  echo "清理npm缓存..."
  npm cache clean --force
  echo "npm缓存清理完成"
}

# 函数：清理Docker构建缓存
clean_docker_cache() {
  echo "清理Docker构建缓存..."
  # 清理悬空镜像
  docker image prune -f
  # 清理构建缓存
  docker builder prune -f
  # 清理所有构建缓存（可选，会清除更多缓存）
  # docker builder prune -a -f
  echo "Docker构建缓存清理完成"
}

# 函数：验证缓存有效性
validate_cache() {
  echo "验证缓存有效性..."
  
  # 检查package-lock.json是否发生变化
  if [[ -f "package-lock.json" ]]; then
    echo "package-lock.json存在，检查完整性..."
    npm ls --depth=0 >/dev/null 2>&1 || {
      echo "依赖不一致，清理npm缓存并重新安装"
      clean_npm_cache
      npm ci
    }
  fi
  
  echo "缓存验证完成"
}

# 函数：优化缓存策略
optimize_cache() {
  echo "优化缓存策略..."
  
  # 设置npm缓存目录
  npm config set cache ~/.npm-cache
  
  # 启用npm缓存验证
  npm config set cache-max 3600
  
  # 启用Docker BuildKit以获得更好的缓存
  export DOCKER_BUILDKIT=1
  
  echo "缓存策略优化完成"
}

# 函数：生成缓存键
generate_cache_key() {
  local project_type=$1
  local cache_version="v1"
  
  case $project_type in
    "nodejs")
      # 基于package-lock.json生成缓存键
      if [[ -f "package-lock.json" ]]; then
        echo "${project_type}-${cache_version}-$(shasum -a 256 package-lock.json | cut -d ' ' -f 1)"
      else
        echo "${project_type}-${cache_version}-default"
      fi
      ;;
    "python")
      # 基于requirements.txt生成缓存键
      if [[ -f "requirements.txt" ]]; then
        echo "${project_type}-${cache_version}-$(shasum -a 256 requirements.txt | cut -d ' ' -f 1)"
      else
        echo "${project_type}-${cache_version}-default"
      fi
      ;;
    *)
      echo "${project_type}-${cache_version}-default"
      ;;
  esac
}

# 主函数
main() {
  local action=${1:-"optimize"}
  
  case $action in
    "clean")
      clean_npm_cache
      clean_docker_cache
      ;;
    "validate")
      validate_cache
      ;;
    "optimize")
      optimize_cache
      ;;
    "key")
      local project_type=${2:-"nodejs"}
      generate_cache_key "$project_type"
      ;;
    *)
      echo "用法: $0 [clean|validate|optimize|key [project_type]]"
      exit 1
      ;;
  esac
}

# 如果脚本直接执行
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi