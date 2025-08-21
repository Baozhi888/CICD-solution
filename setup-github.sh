#!/bin/bash

# GitHub 仓库设置脚本
# 请在创建新仓库后运行此脚本

echo "=== GitHub 仓库设置脚本 ==="
echo

# 检查是否在正确的目录
if [ ! -f "README.md" ]; then
    echo "错误：请在项目根目录运行此脚本"
    exit 1
fi

# 设置远程仓库
echo "1. 设置远程仓库..."
git remote remove origin 2>/dev/null
git remote add origin https://github.com/Baozhi888/CICD-solution.git

# 推送到 main 分支
echo "2. 推送代码到 main 分支..."
git push -u origin main

echo
echo "✅ 完成！代码已推送到新仓库的 main 分支"
echo
echo "仓库地址：https://github.com/Baozhi888/CICD-solution"