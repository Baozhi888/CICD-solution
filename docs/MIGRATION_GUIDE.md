# 脚本库重构迁移指南

## 概述

为了消除代码重复并提升可维护性，我们对脚本库进行了重构：

## 目录结构变更

### 旧结构
```
scripts/
├── logging.sh          # (已删除)
├── utils.sh            # (已删除)
├── validation.sh       # (已删除)
└── ... (其他专用脚本)

shared-scripts/
├── logging.sh          # 基础版本
├── utils.sh            # 基础版本
├── validation.sh       # 基础版本
└── ...
```

### 新结构
```
lib/
├── core/
│   ├── logging.sh      # 增强版日志库
│   ├── utils.sh        # 工具函数库
│   ├── validation.sh   # 验证函数库
│   └── config-manager.sh # 配置管理器
└── core-loader.sh      # 统一加载器

scripts/                # 专用脚本目录
├── generate-docs.sh    # (已更新)
└── ... (其他专用脚本)

shared-scripts/         # 保留用于特殊用途
└── doc-generator.sh    # (已更新)
```

## 迁移步骤

### 1. 更新脚本引用

**旧方式：**
```bash
source ./shared-scripts/logging.sh
source ./shared-scripts/utils.sh
source ./shared-scripts/validation.sh
```

**新方式：**
```bash
source ./lib/core-loader.sh
set_log_module "YourModuleName"
```

### 2. 使用模块化日志

新版本支持模块化日志记录：
```bash
source ./lib/core-loader.sh

# 设置模块名称
set_log_module "MyApp"

# 使用日志函数
log_info "处理开始"
log_debug "调试信息"
log_error "发生错误"
```

### 3. 配置管理器自动初始化

core-loader.sh 会自动初始化配置管理器，无需手动调用：
```bash
source ./lib/core-loader.sh

# 直接使用配置函数
config_value=$(get_config "path.to.config")
```

## 新功能特性

### 1. 统一的日志格式
- 支持模块名称标识
- 自动文件记录
- 颜色区分

### 2. 简化的加载流程
- 单个加载器文件
- 自动依赖管理
- 统一初始化

### 3. 更好的可维护性
- 消除代码重复
- 集中管理核心功能
- 清晰的职责分离

## 兼容性说明

- 所有现有函数保持兼容
- 配置文件格式无需更改
- 日志输出格式略有增强（添加模块名）

## 注意事项

1. 确保 `lib/` 目录与脚本文件同级
2. 模块名称建议使用有意义的标识符
3. 日志文件路径可通过环境变量 `DEFAULT_LOG_FILE` 配置

## 示例

```bash
#!/bin/bash

# 加载核心库
source "$(dirname "$0")/../lib/core-loader.sh"

# 设置模块名称
set_log_module "Deployment"

# 主逻辑
log_info "开始部署流程"

# 获取配置
env=$(get_config "deploy.environment" "development")
log_debug "部署环境: $env"

# 执行部署
if deploy_app "$env"; then
    log_info "部署成功"
else
    log_error "部署失败"
    exit 1
fi
```