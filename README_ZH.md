# 统一 CI/CD 自动化解决方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen.svg)](https://www.shellcheck.net/)
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
- **覆盖率检测**：自动生成测试覆盖率报告

### 🔒 **安全加固**
- **命令注入防护**：安全的命令执行机制
- **敏感数据清理**：安全删除和变量清理
- **代码质量检查**：集成 ShellCheck 静态分析

### 🛠️ **丰富工具**
- **配置向导**：交互式配置生成
- **API 文档生成**：自动提取函数文档
- **配置合并**：YAML 深度合并工具

### 🤖 **AI 监督功能**
- **日志智能分析**：AI 驱动的日志错误检测和根因分析
- **配置审计**：安全检查、性能优化建议
- **健康监控**：系统健康评估和问题预测
- **智能告警**：告警聚合、优先级排序、多渠道通知
- **支持多提供商**：Claude API / OpenAI 兼容 API

### 📦 **企业级模板**
- **GitHub Actions**：完整 CI/CD 流水线模板
- **Docker/Kubernetes**：生产级部署配置
- **Terraform**：AWS 基础设施即代码

### 🔌 **MCP 服务器**
- **对话式管理**：通过 Claude Desktop 对话式管理 CI/CD
- **智能工具**：部署、回滚、分析、配置管理
- **资源访问**：流水线、配置、模板资源查询

## 📁 项目结构

```
cicd-solution/
├── lib/                       # 核心库
│   ├── core/                  # 核心模块
│   │   ├── utils.sh           # 工具函数
│   │   ├── validation.sh      # 验证函数
│   │   ├── logging.sh         # 日志管理
│   │   ├── config-manager.sh  # 配置管理
│   │   ├── error-handler.sh   # 错误处理
│   │   └── enhanced-logging.sh # 增强日志
│   ├── utils/                 # 工具库
│   │   ├── colors.sh          # 统一颜色定义
│   │   └── args-parser.sh     # 参数解析器
│   ├── ai/                    # AI 模块
│   │   ├── ai-core.sh         # AI 核心功能
│   │   ├── api-client.sh      # API 客户端
│   │   ├── log-analyzer.sh    # 日志分析
│   │   ├── config-advisor.sh  # 配置顾问
│   │   ├── health-analyzer.sh # 健康分析
│   │   └── alert-manager.sh   # 告警管理
│   └── core-loader.sh         # 库加载器
├── scripts/                   # 可执行脚本
│   ├── aicd.sh                # 主命令行工具
│   ├── config-wizard.sh       # 交互式配置向导
│   ├── api-docs-generator.sh  # API 文档生成器
│   ├── config-merger.sh       # 配置合并工具
│   ├── lint.sh                # 代码质量检查
│   ├── log-manager.sh         # 日志管理器
│   ├── config-version-manager.sh  # 配置版本管理
│   ├── validate-config.sh     # 配置验证
│   ├── ai-supervisor.sh       # AI 监督工具
│   └── generate-docs.sh       # 文档生成器
├── tests/                     # 测试框架
│   ├── run-tests.sh           # 测试运行器
│   ├── coverage.sh            # 覆盖率检测
│   ├── unit/                  # 单元测试
│   │   ├── test-core.sh       # 核心库测试
│   │   ├── test-aicd.sh       # 主程序测试
│   │   └── test-utils-colors.sh # 颜色库测试
│   └── integration/           # 集成测试
│       └── test-workflow-integration.sh
├── templates/                 # CI/CD 模板
│   ├── github-actions/        # GitHub Actions 工作流
│   │   ├── ci-cd.yaml         # 完整 CI/CD 流水线
│   │   ├── pr-validation.yaml # PR 验证
│   │   └── release.yaml       # 发布流程
│   ├── docker/                # Docker 配置
│   │   ├── Dockerfile.node    # Node.js 多阶段构建
│   │   ├── Dockerfile.python  # Python 多阶段构建
│   │   ├── docker-compose.dev.yaml   # 开发环境
│   │   └── docker-compose.prod.yaml  # 生产环境
│   ├── kubernetes/            # Kubernetes 配置
│   │   ├── deployment.yaml    # 部署配置
│   │   └── ingress.yaml       # Ingress 配置
│   └── terraform/             # Terraform IaC
│       ├── main.tf            # AWS 基础设施
│       └── env/               # 环境变量
├── cicd-mcp-server/           # MCP 服务器
│   ├── src/                   # TypeScript 源码
│   │   ├── tools/             # MCP 工具
│   │   └── resources/         # MCP 资源
│   └── package.json           # 依赖配置
├── config/                    # 配置文件
│   ├── central-config.yaml    # 中央配置
│   └── environment/           # 环境配置
├── docs/                      # 文档
└── .shellcheckrc              # ShellCheck 配置
```

## 🚀 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. 使用配置向导（推荐）

```bash
# 启动交互式配置向导
./scripts/config-wizard.sh

# 或使用快速模式
./scripts/config-wizard.sh --quick

# 或选择预设模板
./scripts/config-wizard.sh --template
```

### 3. 运行测试

```bash
# 运行所有测试
./tests/run-tests.sh

# 只运行单元测试
./tests/run-tests.sh --unit-only

# 生成覆盖率报告
./tests/run-tests.sh --coverage

# 查看详细覆盖率
./tests/coverage.sh --detail
```

### 4. 使用 aicd 命令行工具

```bash
# 显示帮助
./scripts/aicd.sh --help

# 初始化项目
./scripts/aicd.sh init

# 验证配置
./scripts/aicd.sh validate

# 运行构建
./scripts/aicd.sh build

# 运行测试
./scripts/aicd.sh test

# 部署项目
./scripts/aicd.sh deploy
```

## 🛠️ 工具使用

### 配置向导

交互式生成项目配置文件：

```bash
# 完整向导模式
./scripts/config-wizard.sh

# 选择项目模板
./scripts/config-wizard.sh --template
# 支持: node-webapp, node-api, python-api, go-service, java-spring
```

### API 文档生成

从 Shell 脚本自动提取函数文档：

```bash
# 生成 Markdown 文档
./scripts/api-docs-generator.sh

# 生成 HTML 文档
./scripts/api-docs-generator.sh --format html

# 包含私有函数
./scripts/api-docs-generator.sh --private
```

### 配置合并

深度合并多个 YAML 配置文件：

```bash
# 合并两个配置文件
./scripts/config-merger.sh -b base.yaml -o overlay.yaml -O merged.yaml

# 合并环境配置
./scripts/config-merger.sh -e production -O config/production.merged.yaml

# 显示配置差异
./scripts/config-merger.sh --diff base.yaml overlay.yaml

# 预览合并结果
./scripts/config-merger.sh -b base.yaml -o overlay.yaml --dry-run
```

### 代码质量检查

```bash
# 运行 ShellCheck 检查
./scripts/lint.sh

# 只检查特定目录
./scripts/lint.sh --dir scripts

# 启用自动修复建议
./scripts/lint.sh --fix
```

## 🤖 AI 监督功能

### 启用 AI 功能

```bash
# 设置 API 密钥
export CLAUDE_API_KEY="your-api-key"
# 或
export OPENAI_API_KEY="your-api-key"

# 编辑配置启用 AI
# config/ai-config.yaml 中设置 ai.enabled: true
```

### 使用 AI 监督工具

```bash
# 显示 AI 模块状态
./scripts/ai-supervisor.sh status

# 分析日志
./scripts/ai-supervisor.sh analyze-logs /var/log/app.log

# 检测错误并建议修复
./scripts/ai-supervisor.sh detect-errors /var/log/app.log

# 审计配置文件
./scripts/ai-supervisor.sh audit-config config/central-config.yaml

# 安全检查
./scripts/ai-supervisor.sh check-security config/central-config.yaml

# 执行健康检查
./scripts/ai-supervisor.sh health-check

# 生成健康报告
./scripts/ai-supervisor.sh health-report

# 向 AI 提问
./scripts/ai-supervisor.sh ask "如何优化 Docker 镜像大小?"
```

### 通过 aicd 使用 AI

```bash
# 使用 aicd 的 ai 子命令
./scripts/aicd.sh ai status
./scripts/aicd.sh ai analyze-logs /path/to/log
./scripts/aicd.sh ai health
./scripts/aicd.sh ai ask "问题内容"
```

## 🔌 MCP 服务器

项目包含 MCP 服务器，支持通过 Claude Desktop 进行对话式 CI/CD 管理。

### 安装和构建

```bash
cd cicd-mcp-server
npm install
npm run build
```

### 配置 Claude Desktop

在 Claude Desktop 配置文件中添加：

```json
{
  "mcpServers": {
    "cicd": {
      "command": "node",
      "args": ["/path/to/cicd-mcp-server/dist/index.js"],
      "env": {
        "CICD_PROJECT_ROOT": "/path/to/your/project"
      }
    }
  }
}
```

### 对话示例

- "帮我部署 v1.2.0 到 staging"
- "分析最近的部署失败"
- "比较 production 和 staging 的配置差异"
- "回滚到上一个版本"
- "查看系统健康状态"

## 📦 使用模板

### GitHub Actions

```bash
# 复制 CI/CD 工作流
cp templates/github-actions/ci-cd.yaml .github/workflows/

# 复制 PR 验证工作流
cp templates/github-actions/pr-validation.yaml .github/workflows/

# 复制发布工作流
cp templates/github-actions/release.yaml .github/workflows/
```

### Docker

```bash
# 使用 Node.js Dockerfile
cp templates/docker/Dockerfile.node Dockerfile

# 使用开发环境 compose
cp templates/docker/docker-compose.dev.yaml docker-compose.yaml

# 启动开发环境
docker compose up -d
```

### Kubernetes

```bash
# 复制部署配置
cp templates/kubernetes/deployment.yaml k8s/

# 复制 Ingress 配置
cp templates/kubernetes/ingress.yaml k8s/

# 部署到集群
kubectl apply -f k8s/
```

### Terraform

```bash
# 复制基础设施配置
cp -r templates/terraform/ infrastructure/

# 初始化 Terraform
cd infrastructure && terraform init

# 规划变更
terraform plan -var-file="env/production.tfvars"

# 应用变更
terraform apply -var-file="env/production.tfvars"
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

### 运行覆盖率检测

```bash
# 基本覆盖率分析
./tests/coverage.sh

# 详细函数覆盖
./tests/coverage.sh --detail

# 生成 HTML 报告
./tests/coverage.sh --html
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

## 🔒 安全特性

### 命令执行安全

项目使用 `safe_exec_cmd()` 函数替代危险的 `eval`，自动检测并拒绝包含命令注入模式的输入。

### 敏感数据处理

```bash
# 安全删除文件（使用 shred）
secure_delete "/path/to/sensitive/file"

# 清理敏感环境变量
secure_unset_vars
```

### 代码质量

- 所有脚本使用 `set -euo pipefail` 严格模式
- 集成 ShellCheck 静态分析
- 统一的错误处理机制

## 📊 性能特点

- **内存占用**：< 10MB 运行时内存
- **启动时间**：< 100ms
- **并发支持**：支持多任务并行
- **可扩展性**：模块化设计，易于扩展

## 🤝 贡献指南

我们欢迎所有形式的贡献！请查看 [贡献指南](CONTRIBUTING.md)。

### 开发流程

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feature/new-feature`
3. 运行代码检查：`./scripts/lint.sh`
4. 运行测试：`./tests/run-tests.sh`
5. 提交更改：`git commit -m 'Add new feature'`
6. 推送分支：`git push origin feature/new-feature`
7. 创建 Pull Request

### 代码规范

- 遵循 Shell Best Practices
- 通过 ShellCheck 检查
- 添加测试覆盖
- 更新相关文档

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) 开源。

## 🙏 致谢

感谢所有贡献者和以下项目：

- [BMad-Method](https://github.com/bmad-code-org/BMAD-METHOD) - AI 驱动的敏捷开发框架
- [ShellCheck](https://www.shellcheck.net/) - Shell 脚本静态分析工具
- [yq](https://github.com/mikefarah/yq) - YAML 处理工具

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
