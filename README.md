# 统一 CI/CD 自动化解决方案 | Unified CI/CD Automation Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen.svg)](https://www.shellcheck.net/)
[![BMad-Method](https://img.shields.io/badge/Powered%20By-BMad--Method-green.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/Baozhi888/CICD-solution)
[![Kubernetes](https://img.shields.io/badge/kubernetes-%23326ce5.svg?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Docker](https://img.shields.io/badge/docker-%230db7ed.svg?style=flat&logo=docker&logoColor=white)](https://docker.com)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io)

A lightweight, modular CI/CD automation solution built with Bash scripts, integrated with BMad-Method agile development framework. Designed for small to medium teams and individual developers.

一个轻量级、模块化的 CI/CD 自动化解决方案，基于 Bash 脚本构建，集成了 BMad-Method 敏捷开发框架。专为中小型团队和个人开发者设计。

## 🌍 语言选择 | Language Selection

Please select your preferred language:

请选择您偏好的语言：

### [🇨🇳 中文文档 (Chinese)](README_ZH.md)
- 完整的中文文档和使用指南
- 详细的配置说明和示例
- 适合中文用户阅读

### [🇺🇸 English Documentation](README_EN.md)
- Complete English documentation and usage guide
- Detailed configuration instructions and examples
- Suitable for English-speaking users

## ✨ Key Features | 核心特性

- 🚀 **Zero Dependencies | 零依赖**: Pure Bash implementation
- 🏗️ **Modular Architecture | 模块化架构**: Shared libraries and configuration-driven
- 🧪 **Complete Testing | 完整测试**: Unit tests, integration tests, coverage reports
- 🔒 **Security Hardened | 安全加固**: Command injection protection, secure data handling
- 🛠️ **Rich Tools | 丰富工具**: Config wizard, API docs generator, config merger
- 🤖 **AI Supervision | AI监督**: Smart log analysis, config audit, health monitoring
- 📦 **Enterprise Templates | 企业模板**: GitHub Actions, Docker/K8s, Terraform
- 🔌 **MCP Server | MCP服务器**: Conversational CI/CD management via Claude Desktop

## 📖 Documentation | 文档

- **[User Guide | 使用指南](docs/user-guide.md)** - Complete user guide with step-by-step instructions
- **[Developer Guide](docs/DEVELOPER_GUIDE.md)** - For contributors and developers
- **[Architecture Patterns](docs/architecture-patterns.md)** - Design patterns and best practices
- **[Migration Guide](docs/MIGRATION_GUIDE.md)** - Migrate from other CI/CD systems
- **[Security Best Practices](docs/security-best-practices.md)** - Security guidelines and recommendations
- **[Templates Guide](templates/README.md)** - CI/CD and IaC template documentation

## 🚀 Quick Start | 快速开始

```bash
# Clone the project | 克隆项目
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution

# Use the config wizard | 使用配置向导
./scripts/config-wizard.sh

# Run tests | 运行测试
./tests/run-tests.sh

# Use the aicd CLI | 使用 aicd 命令行工具
./scripts/aicd.sh --help
```

## 📁 Project Structure | 项目结构

```
cicd-solution/
├── lib/                    # Core libraries | 核心库
│   ├── core/               # Core modules | 核心模块
│   └── utils/              # Utility libraries | 工具库
├── scripts/                # Executable scripts | 可执行脚本
│   ├── aicd.sh             # Main CLI tool | 主命令行工具
│   ├── config-wizard.sh    # Config wizard | 配置向导
│   ├── api-docs-generator.sh  # API docs | API文档生成
│   ├── config-merger.sh    # Config merger | 配置合并
│   └── lint.sh             # Code linter | 代码检查
├── tests/                  # Testing framework | 测试框架
│   ├── unit/               # Unit tests | 单元测试
│   ├── integration/        # Integration tests | 集成测试
│   └── coverage.sh         # Coverage report | 覆盖率报告
├── templates/              # CI/CD templates | CI/CD模板
│   ├── github-actions/     # GitHub Actions workflows
│   ├── docker/             # Docker & Compose configs
│   ├── kubernetes/         # K8s deployment configs
│   └── terraform/          # Terraform IaC
├── cicd-mcp-server/        # MCP Server for Claude Desktop
│   ├── src/                # TypeScript source
│   │   ├── tools/          # MCP Tools
│   │   └── resources/      # MCP Resources
│   └── package.json        # Dependencies
├── config/                 # Configuration | 配置文件
├── docs/                   # Documentation | 文档
└── examples/               # Examples | 示例项目
```

## 🛠️ Tools | 工具

| Tool | Description |
|------|-------------|
| `config-wizard.sh` | Interactive configuration generator |
| `api-docs-generator.sh` | Auto-generate API docs from scripts |
| `config-merger.sh` | Deep merge YAML configurations |
| `lint.sh` | ShellCheck code quality analysis |
| `coverage.sh` | Test coverage detection & reports |
| `ai-supervisor.sh` | AI-powered supervision and analysis |

## 🔌 MCP Server | MCP 服务器

The project includes an MCP Server for conversational CI/CD management with Claude Desktop.

本项目包含 MCP 服务器，支持通过 Claude Desktop 进行对话式 CI/CD 管理。

```bash
# Install and build | 安装和构建
cd cicd-mcp-server
npm install
npm run build
```

Configure in Claude Desktop:
```json
{
  "mcpServers": {
    "cicd": {
      "command": "node",
      "args": ["/path/to/cicd-mcp-server/dist/index.js"]
    }
  }
}
```

Example conversations | 对话示例:
- "帮我部署 v1.2.0 到 staging"
- "分析最近的部署失败"
- "比较 production 和 staging 的配置"

## 📦 Templates | 模板

| Template | Description |
|----------|-------------|
| GitHub Actions | CI/CD pipeline, PR validation, release workflows |
| Docker | Multi-stage Dockerfiles, dev/prod compose configs |
| Kubernetes | Deployment, HPA, Ingress, NetworkPolicy |
| Terraform | AWS infrastructure (VPC, EKS, RDS, ElastiCache) |

## 🤝 Contributing | 贡献

We welcome all forms of contributions! Please read our [Contribution Guide](CONTRIBUTING.md).

我们欢迎所有形式的贡献！请阅读我们的[贡献指南](CONTRIBUTING.md)。

```bash
# Run linter before commit
./scripts/lint.sh

# Run tests
./tests/run-tests.sh
```

## 📄 License | 许可证

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

本项目采用 MIT 许可证开源 - 详情请查看 [LICENSE](LICENSE) 文件。

## 📞 Support | 支持

- 📧 Email: kj331704@gmail.com
- 💬 Discussions: [GitHub Discussions](https://github.com/Baozhi888/CICD-solution/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/Baozhi888/CICD-solution/issues)

---

<div align="center">
Made with ❤️ by KingJohn
</div>
