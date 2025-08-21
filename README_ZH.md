# 统一 CI/CD 自动化解决方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![BMad-Method](https://img.shields.io/badge/Powered%20By-BMad--Method-green.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![中文文档](https://img.shields.io/badge/文档-中文-blue.svg)](README.md)

一个轻量级、模块化的 CI/CD 自动化解决方案，基于 Bash 脚本构建，集成了 BMad-Method 敏捷开发框架。专为中小型团队和个人开发者设计，开箱即用。

[**English**](README_EN.md) | **中文**

## ✨ 核心特性

### 🚀 **开箱即用**
- **零依赖**：纯 Bash 实现，无需安装额外依赖
- **跨平台**：支持 Linux、macOS、Windows (WSL)
- **快速部署**：5 分钟内完成配置和运行

### 🏗️ **模块化架构**
- **共享库**：避免代码重复，提高复用性
- **配置驱动**：YAML 配置文件管理所有行为
- **环境感知**：支持多环境配置覆盖

### 🧪 **完整测试**
- **单元测试**：内置 Shell 脚本测试框架
- **集成测试**：端到端流程验证
- **测试报告**：详细的测试结果和覆盖率

### 🔄 **智能功能**
- **日志轮转**：自动清理和归档日志
- **版本管理**：配置变更追踪和回滚
- **错误处理**：统一的错误报告机制

### 🤖 **AI 增强**
- **BMad-Method**：AI 驱动的敏捷开发框架
- **智能代理**：自动化任务执行和代码生成
- **协作流程**：多角色 AI 代理协作

## 📁 项目结构

```
cicd-solution/
├── lib/                    # 核心库
│   └── core/              # 核心模块
│       ├── utils.sh       # 工具函数
│       ├── validation.sh  # 验证函数
│       ├── logging.sh     # 日志管理
│       ├── config-manager.sh  # 配置管理
│       ├── error-handler.sh   # 错误处理
│       └── enhanced-logging.sh # 增强日志
├── scripts/               # 可执行脚本
│   ├── log-manager.sh     # 日志管理器
│   ├── config-version-manager.sh  # 配置版本管理
│   └── generate-docs.sh   # 文档生成器
├── tests/                 # 测试框架
│   ├── test-framework.sh  # 测试框架
│   ├── run-tests.sh       # 测试运行器
│   └── unit/              # 单元测试
├── templates/             # CI/CD 模板
│   ├── github/           # GitHub Actions
│   ├── gitlab/           # GitLab CI
│   └── jenkins/          # Jenkins
├── config/               # 配置文件
│   ├── central-config.yaml  # 中央配置
│   └── environment/      # 环境配置
├── docs/                 # 文档
├── examples/             # 示例项目
└── .bmad-core/           # BMad-Method 集成
```

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. 配置项目

编辑 `config/central-config.yaml`：

```yaml
# 基础配置
project:
  name: "my-project"
  version: "1.0.0"

# 环境配置
environments:
  development:
    debug: true
    log_level: "DEBUG"
  production:
    debug: false
    log_level: "INFO"

# CI/CD 配置
ci_cd:
  build_command: "npm run build"
  test_command: "npm test"
  deploy_command: "./scripts/deploy.sh"
```

### 3. 运行测试

```bash
# 运行所有测试
./tests/run-tests.sh

# 运行特定测试
./tests/run-tests.sh --unit-only

# 详细输出
./tests/run-tests.sh --verbose
```

### 4. 集成到 CI/CD

#### GitHub Actions

```yaml
name: CI/CD Pipeline

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: ./tests/run-tests.sh
```

## 📖 使用指南

### 核心脚本

#### 日志管理
```bash
# 启动日志管理器
./scripts/log-manager.sh start

# 查看日志状态
./scripts/log-manager.sh status

# 清理旧日志
./scripts/log-manager.sh cleanup
```

#### 配置版本管理
```bash
# 创建配置版本
./scripts/config-version-manager.sh create "Add new feature"

# 查看版本历史
./scripts/config-version-manager.sh history

# 回滚到指定版本
./scripts/config-version-manager.sh rollback v1.0.0
```

### 使用共享库

```bash
# 加载核心库
source ./lib/core-loader.sh

# 使用工具函数
trim_string=$(trim "  hello world  ")
is_valid=$(is_email "test@example.com")
log_info "This is an info message"
```

## 🧪 测试框架

### 编写测试

```bash
#!/bin/bash
# tests/unit/test-example.sh

source ../test-framework.sh

test_example_function() {
    # 测试断言
    assert_equals "expected" "actual" "Test description"
    assert_command_succeeds "ls /tmp" "Command should succeed"
    assert_file_exists "/tmp/test.txt" "File should exist"
}

# 运行测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    test_init
    run_test_suite "Example" test_example_function
    print_test_summary
fi
```

## 🔧 配置说明

### 环境变量覆盖

```bash
# 覆盖配置文件中的值
export CFG_PROJECT_NAME="new-name"
export CFG_LOG_LEVEL="DEBUG"
```

### 配置优先级

1. 环境变量（最高）
2. 环境特定配置（`config/environment/{env}.yaml`）
3. 本地配置（`./config.yaml`）
4. 中央配置（`config/central-config.yaml`）
5. 默认值（最低）

## 🤖 BMad-Method 集成

本项目集成了 BMad-Method，提供 AI 驱动的开发体验：

### 可用命令

- `/bmad-master` - 主执行器
- `/bmad-orchestrator` - 协调器
- `/dev` - 开发代理
- `/qa` - 质量保证代理
- `/pm` - 项目管理代理

### 工作流程

1. **规划阶段**：使用 Web UI 创建 PRD 和架构文档
2. **开发阶段**：通过 IDE 实施用户故事
3. **测试阶段**：自动化测试和代码审查
4. **部署阶段**：自动化部署和监控

## 📊 性能特点

- **内存占用**：< 10MB 运行时内存
- **启动时间**：< 100ms
- **并发支持**：支持多任务并行
- **可扩展性**：模块化设计，易于扩展

## 🛡️ 安全特性

- **敏感信息保护**：自动过滤密钥和密码
- **权限控制**：基于文件系统的权限管理
- **审计日志**：完整的操作记录
- **安全扫描**：集成安全检查工具

## 🤝 贡献指南

我们欢迎所有形式的贡献！请查看 [贡献指南](CONTRIBUTING.md)。

### 开发流程

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 提交更改：`git commit -m 'Add new feature'`
4. 推送分支：`git push origin feature/new-feature`
5. 创建 Pull Request

### 代码规范

- 遵循 Shell Best Practices
- 添加测试覆盖
- 更新相关文档
- 确保 CI/CD 通过

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

## 🙏 致谢

感谢所有贡献者和以下项目：

- [BMad-Method](https://github.com/bmad-code-org/BMAD-METHOD) - AI 驱动的敏捷开发框架
- [ShellCheck](https://www.shellcheck.net/) - Shell 脚本静态分析工具
- [Bash Boilerplate](https://github.com/termux/bash-boilerplate) - Bash 脚本最佳实践

## 📞 支持

- 📧 邮箱：kj331704@gmail.com
- 💬 讨论：[GitHub Discussions](https://github.com/Baozhi888/CICD-solution/discussions)
- 🐛 问题：[GitHub Issues](https://github.com/Baozhi888/CICD-solution/issues)

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Baozhi888/CICD-solution&type=Date)](https://star-history.com/#Baozhi888/CICD-solution&Date)

---

<div align="center">
Made with ❤️ by KingJohn
</div>