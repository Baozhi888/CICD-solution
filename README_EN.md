# Unified CI/CD Automation Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)
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
- **Test Reports**: Detailed test results and coverage

### 🔄 **Smart Features**
- **Log Rotation**: Automatic cleanup and archiving of logs
- **Version Management**: Configuration change tracking and rollback
- **Error Handling**: Unified error reporting mechanism

### 🤖 **AI Enhanced**
- **BMad-Method**: AI-driven agile development framework
- **Smart Agents**: Automated task execution and code generation
- **Collaborative Workflow**: Multi-role AI agent collaboration

## 📁 Project Structure

```
cicd-solution/
├── lib/                    # Core libraries
│   └── core/              # Core modules
│       ├── utils.sh       # Utility functions
│       ├── validation.sh  # Validation functions
│       ├── logging.sh     # Logging management
│       ├── config-manager.sh  # Configuration management
│       ├── error-handler.sh   # Error handling
│       └── enhanced-logging.sh # Enhanced logging
├── scripts/               # Executable scripts
│   ├── log-manager.sh     # Log manager
│   ├── config-version-manager.sh  # Configuration version manager
│   └── generate-docs.sh   # Documentation generator
├── tests/                 # Testing framework
│   ├── test-framework.sh  # Test framework
│   ├── run-tests.sh       # Test runner
│   └── unit/              # Unit tests
├── templates/             # CI/CD templates
│   ├── github/           # GitHub Actions
│   ├── gitlab/           # GitLab CI
│   └── jenkins/          # Jenkins
├── config/               # Configuration files
│   ├── central-config.yaml  # Central configuration
│   └── environment/      # Environment configurations
├── docs/                 # Documentation
├── examples/             # Example projects
└── .bmad-core/           # BMad-Method integration
```

## 🚀 Quick Start

### 1. Clone the Project

```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. Configure the Project

Edit `config/central-config.yaml`:

```yaml
# Basic configuration
project:
  name: "my-project"
  version: "1.0.0"

# Environment configuration
environments:
  development:
    debug: true
    log_level: "DEBUG"
  production:
    debug: false
    log_level: "INFO"

# CI/CD configuration
ci_cd:
  build_command: "npm run build"
  test_command: "npm test"
  deploy_command: "./scripts/deploy.sh"
```

### 3. Run Tests

```bash
# Run all tests
./tests/run-tests.sh

# Run specific tests
./tests/run-tests.sh --unit-only

# Verbose output
./tests/run-tests.sh --verbose
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

### 4. Integrate with CI/CD

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

## 📖 Usage Guide

### Core Scripts

#### Log Management
```bash
# Start log manager
./scripts/log-manager.sh start

# Check log status
./scripts/log-manager.sh status

# Clean old logs
./scripts/log-manager.sh cleanup
```

#### Configuration Version Management
```bash
# Create configuration version
./scripts/config-version-manager.sh create "Add new feature"

# View version history
./scripts/config-version-manager.sh history

# Rollback to specific version
./scripts/config-version-manager.sh rollback v1.0.0
```

### Using Shared Libraries

```bash
# Load core library
source ./lib/core-loader.sh

# Use utility functions
trim_string=$(trim "  hello world  ")
is_valid=$(is_email "test@example.com")
log_info "This is an info message"
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

## 🤖 BMad-Method Integration

This project integrates BMad-Method, providing AI-driven development experience:

### Available Commands

- `/bmad-master` - Master executor
- `/bmad-orchestrator` - Orchestrator
- `/dev` - Development agent
- `/qa` - Quality assurance agent
- `/pm` - Project management agent

### Workflow

1. **Planning Phase**: Use Web UI to create PRD and architecture documents
2. **Development Phase**: Implement user stories through IDE
3. **Testing Phase**: Automated testing and code review
4. **Deployment Phase**: Automated deployment and monitoring

## 📊 Performance Characteristics

- **Memory Usage**: < 10MB runtime memory
- **Startup Time**: < 100ms
- **Concurrent Support**: Supports multi-task parallel execution
- **Scalability**: Modular design, easy to extend

## 🛡️ Security Features

- **Sensitive Information Protection**: Automatic filtering of keys and passwords
- **Access Control**: Filesystem-based permission management
- **Audit Logs**: Complete operation records
- **Security Scanning**: Integrated security check tools

## 🤝 Contributing

We welcome all forms of contributions! Please check the [Contribution Guide](CONTRIBUTING.md).

### Development Workflow

1. Fork this repository
2. Create a feature branch: `git checkout -b feature/new-feature`
3. Commit your changes: `git commit -m 'Add new feature'`
4. Push the branch: `git push origin feature/new-feature`
5. Create a Pull Request

### Code Standards

- Follow Shell Best Practices
- Add test coverage
- Update relevant documentation
- Ensure CI/CD passes

## 📄 License

This project is open sourced under the [MIT License](LICENSE).

## 🙏 Acknowledgments

Thanks to all contributors and the following projects:

- [BMad-Method](https://github.com/bmad-code-org/BMAD-METHOD) - AI-driven agile development framework
- [ShellCheck](https://www.shellcheck.net/) - Shell script static analysis tool
- [Bash Boilerplate](https://github.com/termux/bash-boilerplate) - Bash script best practices

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