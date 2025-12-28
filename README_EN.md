# Unified CI/CD Automation Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
[![ShellCheck](https://img.shields.io/badge/ShellCheck-Passed-brightgreen.svg)](https://www.shellcheck.net/)
[![BMad-Method](https://img.shields.io/badge/Powered%20By-BMad--Method-green.svg)](https://github.com/bmad-code-org/BMAD-METHOD)
[![English Docs](https://img.shields.io/badge/docs-English-blue.svg)](README_EN.md)

A lightweight, modular CI/CD automation solution built with Bash scripts, integrated with BMad-Method agile development framework. Designed for small to medium teams and individual developers, ready to use out of the box.

**English** | [**中文**](README_ZH.md)

## ✨ Core Features

### 🚀 **Ready to Use**
- **Zero Dependencies**: Pure Bash implementation, no additional dependencies required
- **Cross Platform**: Supports Linux, macOS, Windows (WSL)
- **Quick Deployment**: Complete configuration and running within 5 minutes

### 🏗️ **Modular Architecture**
- **Shared Libraries**: Avoid code duplication, improve reusability
- **Configuration Driven**: YAML configuration files manage all behaviors
- **Environment Aware**: Supports multi-environment configuration overrides

### 🧪 **Complete Testing**
- **Unit Tests**: Built-in Shell script testing framework
- **Integration Tests**: End-to-end process validation
- **Coverage Reports**: Automatic test coverage detection

### 🔒 **Security Hardened**
- **Command Injection Protection**: Safe command execution mechanism
- **Sensitive Data Cleanup**: Secure file deletion and variable cleanup
- **Code Quality Check**: Integrated ShellCheck static analysis

### 🛠️ **Rich Tools**
- **Config Wizard**: Interactive configuration generation
- **API Docs Generator**: Auto-extract function documentation
- **Config Merger**: YAML deep merge tool

### 🤖 **AI Supervision**
- **Smart Log Analysis**: AI-driven error detection and root cause analysis
- **Config Audit**: Security checks, performance optimization suggestions
- **Health Monitoring**: System health assessment and issue prediction
- **Smart Alerting**: Alert aggregation, prioritization, multi-channel notification
- **Multi-Provider Support**: Claude API / OpenAI compatible API

### 📦 **Enterprise Templates**
- **GitHub Actions**: Complete CI/CD pipeline templates
- **Docker/Kubernetes**: Production-grade deployment configs
- **Terraform**: AWS Infrastructure as Code

### 🔌 **MCP Server**
- **Conversational Management**: Manage CI/CD via Claude Desktop chat
- **Smart Tools**: Deploy, rollback, analyze, config management
- **Resource Access**: Query pipelines, configs, and templates

## 📁 Project Structure

```
cicd-solution/
├── lib/                       # Core libraries
│   ├── core/                  # Core modules
│   │   ├── utils.sh           # Utility functions
│   │   ├── validation.sh      # Validation functions
│   │   ├── logging.sh         # Logging management
│   │   ├── config-manager.sh  # Configuration management
│   │   ├── error-handler.sh   # Error handling
│   │   └── enhanced-logging.sh # Enhanced logging
│   ├── utils/                 # Utility libraries
│   │   ├── colors.sh          # Unified color definitions
│   │   └── args-parser.sh     # Argument parser
│   ├── ai/                    # AI modules
│   │   ├── ai-core.sh         # AI core functionality
│   │   ├── api-client.sh      # API client
│   │   ├── log-analyzer.sh    # Log analysis
│   │   ├── config-advisor.sh  # Config advisor
│   │   ├── health-analyzer.sh # Health analyzer
│   │   └── alert-manager.sh   # Alert manager
│   └── core-loader.sh         # Library loader
├── scripts/                   # Executable scripts
│   ├── aicd.sh                # Main CLI tool
│   ├── config-wizard.sh       # Interactive config wizard
│   ├── api-docs-generator.sh  # API documentation generator
│   ├── config-merger.sh       # Configuration merge tool
│   ├── lint.sh                # Code quality checker
│   ├── log-manager.sh         # Log manager
│   ├── config-version-manager.sh  # Config version manager
│   ├── validate-config.sh     # Configuration validator
│   ├── ai-supervisor.sh       # AI supervision tool
│   └── generate-docs.sh       # Documentation generator
├── tests/                     # Testing framework
│   ├── run-tests.sh           # Test runner
│   ├── coverage.sh            # Coverage detection
│   ├── unit/                  # Unit tests
│   │   ├── test-core.sh       # Core library tests
│   │   ├── test-aicd.sh       # Main program tests
│   │   └── test-utils-colors.sh # Color library tests
│   └── integration/           # Integration tests
│       └── test-workflow-integration.sh
├── templates/                 # CI/CD templates
│   ├── github-actions/        # GitHub Actions workflows
│   │   ├── ci-cd.yaml         # Complete CI/CD pipeline
│   │   ├── pr-validation.yaml # PR validation
│   │   └── release.yaml       # Release workflow
│   ├── docker/                # Docker configurations
│   │   ├── Dockerfile.node    # Node.js multi-stage build
│   │   ├── Dockerfile.python  # Python multi-stage build
│   │   ├── docker-compose.dev.yaml   # Development environment
│   │   └── docker-compose.prod.yaml  # Production environment
│   ├── kubernetes/            # Kubernetes configurations
│   │   ├── deployment.yaml    # Deployment config
│   │   └── ingress.yaml       # Ingress config
│   └── terraform/             # Terraform IaC
│       ├── main.tf            # AWS infrastructure
│       └── env/               # Environment variables
├── cicd-mcp-server/           # MCP Server
│   ├── src/                   # TypeScript source
│   │   ├── tools/             # MCP Tools
│   │   └── resources/         # MCP Resources
│   └── package.json           # Dependencies
├── config/                    # Configuration files
│   ├── central-config.yaml    # Central configuration
│   └── environment/           # Environment configs
├── docs/                      # Documentation
└── .shellcheckrc              # ShellCheck configuration
```

## 🚀 Quick Start

### 1. Clone the Project

```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. Use Configuration Wizard (Recommended)

```bash
# Start interactive configuration wizard
./scripts/config-wizard.sh

# Or use quick mode
./scripts/config-wizard.sh --quick

# Or select a preset template
./scripts/config-wizard.sh --template
```

### 3. Run Tests

```bash
# Run all tests
./tests/run-tests.sh

# Run unit tests only
./tests/run-tests.sh --unit-only

# Generate coverage report
./tests/run-tests.sh --coverage

# View detailed coverage
./tests/coverage.sh --detail
```

### 4. Use the aicd CLI

```bash
# Show help
./scripts/aicd.sh --help

# Initialize project
./scripts/aicd.sh init

# Validate configuration
./scripts/aicd.sh validate

# Run build
./scripts/aicd.sh build

# Run tests
./scripts/aicd.sh test

# Deploy
./scripts/aicd.sh deploy
```

## 🛠️ Tool Usage

### Configuration Wizard

Interactively generate project configuration files:

```bash
# Full wizard mode
./scripts/config-wizard.sh

# Select project template
./scripts/config-wizard.sh --template
# Supports: node-webapp, node-api, python-api, go-service, java-spring
```

### API Documentation Generator

Auto-extract function documentation from Shell scripts:

```bash
# Generate Markdown documentation
./scripts/api-docs-generator.sh

# Generate HTML documentation
./scripts/api-docs-generator.sh --format html

# Include private functions
./scripts/api-docs-generator.sh --private
```

### Configuration Merger

Deep merge multiple YAML configuration files:

```bash
# Merge two configuration files
./scripts/config-merger.sh -b base.yaml -o overlay.yaml -O merged.yaml

# Merge environment configuration
./scripts/config-merger.sh -e production -O config/production.merged.yaml

# Show configuration diff
./scripts/config-merger.sh --diff base.yaml overlay.yaml

# Preview merge result
./scripts/config-merger.sh -b base.yaml -o overlay.yaml --dry-run
```

### Code Quality Check

```bash
# Run ShellCheck
./scripts/lint.sh

# Check specific directory only
./scripts/lint.sh --dir scripts

# Enable auto-fix suggestions
./scripts/lint.sh --fix
```

## 🤖 AI Supervision

### Enable AI Features

```bash
# Set API key
export CLAUDE_API_KEY="your-api-key"
# Or
export OPENAI_API_KEY="your-api-key"

# Edit config to enable AI
# Set ai.enabled: true in config/ai-config.yaml
```

### Using AI Supervisor Tool

```bash
# Show AI module status
./scripts/ai-supervisor.sh status

# Analyze logs
./scripts/ai-supervisor.sh analyze-logs /var/log/app.log

# Detect errors and suggest fixes
./scripts/ai-supervisor.sh detect-errors /var/log/app.log

# Audit configuration file
./scripts/ai-supervisor.sh audit-config config/central-config.yaml

# Security check
./scripts/ai-supervisor.sh check-security config/central-config.yaml

# Execute health check
./scripts/ai-supervisor.sh health-check

# Generate health report
./scripts/ai-supervisor.sh health-report

# Ask AI a question
./scripts/ai-supervisor.sh ask "How to optimize Docker image size?"
```

### Using AI via aicd

```bash
# Use aicd's ai subcommand
./scripts/aicd.sh ai status
./scripts/aicd.sh ai analyze-logs /path/to/log
./scripts/aicd.sh ai health
./scripts/aicd.sh ai ask "your question"
```

## 🔌 MCP Server

The project includes an MCP Server for conversational CI/CD management with Claude Desktop.

### Installation

```bash
cd cicd-mcp-server
npm install
npm run build
```

### Configure Claude Desktop

Add to your Claude Desktop config:

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

### Example Conversations

- "Deploy v1.2.0 to staging for me"
- "Analyze the recent deployment failure"
- "Compare production and staging configs"
- "Rollback to the previous version"
- "Show system health status"

## 📦 Using Templates

### GitHub Actions

```bash
# Copy CI/CD workflow
cp templates/github-actions/ci-cd.yaml .github/workflows/

# Copy PR validation workflow
cp templates/github-actions/pr-validation.yaml .github/workflows/

# Copy release workflow
cp templates/github-actions/release.yaml .github/workflows/
```

### Docker

```bash
# Use Node.js Dockerfile
cp templates/docker/Dockerfile.node Dockerfile

# Use development compose
cp templates/docker/docker-compose.dev.yaml docker-compose.yaml

# Start development environment
docker compose up -d
```

### Kubernetes

```bash
# Copy deployment configuration
cp templates/kubernetes/deployment.yaml k8s/

# Copy Ingress configuration
cp templates/kubernetes/ingress.yaml k8s/

# Deploy to cluster
kubectl apply -f k8s/
```

### Terraform

```bash
# Copy infrastructure configuration
cp -r templates/terraform/ infrastructure/

# Initialize Terraform
cd infrastructure && terraform init

# Plan changes
terraform plan -var-file="env/production.tfvars"

# Apply changes
terraform apply -var-file="env/production.tfvars"
```

## 🧪 Testing Framework

### Writing Tests

```bash
#!/bin/bash
# tests/unit/test-example.sh

source ../test-framework.sh

test_example_function() {
    # Test assertions
    assert_equals "expected" "actual" "Test description"
    assert_command_succeeds "ls /tmp" "Command should succeed"
    assert_file_exists "/tmp/test.txt" "File should exist"
}

# Run tests
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    test_init
    run_test_suite "Example" test_example_function
    print_test_summary
fi
```

### Running Coverage Detection

```bash
# Basic coverage analysis
./tests/coverage.sh

# Detailed function coverage
./tests/coverage.sh --detail

# Generate HTML report
./tests/coverage.sh --html
```

## 🔧 Configuration

### Environment Variable Override

```bash
# Override values in configuration file
export CFG_PROJECT_NAME="new-name"
export CFG_LOG_LEVEL="DEBUG"
```

### Configuration Priority

1. Environment variables (highest)
2. Environment-specific configuration (`config/environment/{env}.yaml`)
3. Local configuration (`./config.yaml`)
4. Central configuration (`config/central-config.yaml`)
5. Default values (lowest)

## 🔒 Security Features

### Safe Command Execution

The project uses `safe_exec_cmd()` function to replace dangerous `eval`, automatically detecting and rejecting inputs containing command injection patterns.

### Sensitive Data Handling

```bash
# Secure file deletion (using shred)
secure_delete "/path/to/sensitive/file"

# Cleanup sensitive environment variables
secure_unset_vars
```

### Code Quality

- All scripts use `set -euo pipefail` strict mode
- Integrated ShellCheck static analysis
- Unified error handling mechanism

## 📊 Performance Characteristics

- **Memory Usage**: < 10MB runtime memory
- **Startup Time**: < 100ms
- **Concurrent Support**: Supports multi-task parallel execution
- **Scalability**: Modular design, easy to extend

## 🤝 Contributing

We welcome all forms of contributions! Please check the [Contribution Guide](CONTRIBUTING.md).

### Development Workflow

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Run code check: `./scripts/lint.sh`
4. Run tests: `./tests/run-tests.sh`
5. Commit your changes: `git commit -m 'Add new feature'`
6. Push the branch: `git push origin feature/new-feature`
7. Create a Pull Request

### Code Standards

- Follow Shell Best Practices
- Pass ShellCheck validation
- Add test coverage
- Update relevant documentation

## 📄 License

This project is open sourced under the [MIT License](LICENSE).

## 🙏 Acknowledgments

Thanks to all contributors and the following projects:

- [BMad-Method](https://github.com/bmad-code-org/BMAD-METHOD) - AI-driven agile development framework
- [ShellCheck](https://www.shellcheck.net/) - Shell script static analysis tool
- [yq](https://github.com/mikefarah/yq) - YAML processing tool

## 📞 Support

- 📧 Email: kj331704@gmail.com
- 💬 Discussions: [GitHub Discussions](https://github.com/Baozhi888/CICD-solution/discussions)
- 🐛 Issues: [GitHub Issues](https://github.com/Baozhi888/CICD-solution/issues)

## 🌟 Star History

[![Star History Chart](https://api.star-history.com/svg?repos=Baozhi888/CICD-solution&type=Date)](https://star-history.com/#Baozhi888/CICD-solution&Date)

---

<div align="center">
Made with ❤️ by KingJohn
</div>
