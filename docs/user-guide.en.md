# 📖 CICD-solution User Guide

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

This guide will help you quickly get started and make the most of CICD-solution features.

[中文版本](user-guide.zh.md) | **English**

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [System Requirements](#system-requirements)
- [Installation & Configuration](#installation--configuration)
- [Basic Usage](#basic-usage)
- [Advanced Features](#advanced-features)
- [Integration Guide](#integration-guide)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

## 🚀 Quick Start

### 1. Clone the Project
```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. Set Execution Permissions
```bash
# Add execute permissions to all scripts
chmod +x scripts/*.sh
chmod +x tests/*.sh
```

### 3. Run Tests to Verify
```bash
./tests/run-tests.sh
```

## 🖥️ System Requirements

- **Operating System**: Linux, macOS, Windows (WSL)
- **Shell**: Bash 4.0+
- **Memory**: Minimum 512MB
- **Storage**: Minimum 100MB
- **Network**: Optional (for downloading dependencies)

## 📦 Installation & Configuration

### Basic Configuration

1. **Edit Central Configuration File**
   ```bash
   nano config/central-config.yaml
   ```

2. **Set Project Information**
   ```yaml
   project:
     name: "my-project"
     version: "1.0.0"
   
   environments:
     development:
       debug: true
       log_level: "DEBUG"
     production:
       debug: false
       log_level: "INFO"
   ```

3. **Configure Build and Deployment**
   ```yaml
   ci_cd:
     build_command: "npm run build"
     test_command: "npm test"
     deploy_command: "./scripts/deploy.sh"
   ```

### Environment Variables Configuration

Create `.env` file:
```bash
# Project configuration
export CFG_PROJECT_NAME="my-project"
export CFG_ENVIRONMENT="development"

# Logging configuration
export CFG_LOG_LEVEL="INFO"
export CFG_LOG_DIR="/var/log/cicd"

# Deployment configuration
export CFG_DEPLOY_TARGET="kubernetes"
export CFG_KUBE_CONTEXT="my-cluster"
```

## 🔧 Basic Usage

### Using the aicd Command Line Tool

```bash
# Show help information
./scripts/aicd.sh --help

# Initialize project
./scripts/aicd.sh init

# Validate configuration
./scripts/aicd.sh validate

# Run build
./scripts/aicd.sh build

# Run tests
./scripts/aicd.sh test

# Deploy to specified environment
./scripts/aicd.sh deploy --env production

# Rollback deployment
./scripts/aicd.sh rollback --version v1.0.0
```

### Log Management

```bash
# Start log manager
./scripts/log-manager.sh start

# Check log status
./scripts/log-manager.sh status

# Clean old logs (keep last 7 days)
./scripts/log-manager.sh cleanup --days 7

# View real-time logs
./scripts/log-manager.sh tail --follow

# Export logs
./scripts/log-manager.sh export --format json --output logs.json
```

### Configuration Version Management

```bash
# Create configuration version
./scripts/config-version-manager.sh create "Add new feature configuration"

# View version history
./scripts/config-version-manager.sh history

# Compare version differences
./scripts/config-version-manager.sh diff v1.0.0 v1.1.0

# Rollback to specified version
./scripts/config-version-manager.sh rollback v1.0.0

# Mark version as stable
./scripts/config-version-manager.sh tag v1.0.0 stable
```

## 🚀 Advanced Features

### 1. Custom Build Pipeline

Create custom pipeline configuration `config/pipeline.yaml`:
```yaml
stages:
  - name: "install"
    command: "npm install"
    timeout: 300
    
  - name: "lint"
    command: "npm run lint"
    continue_on_error: false
    
  - name: "test"
    command: "npm test"
    coverage: true
    
  - name: "build"
    command: "npm run build"
    artifacts:
      - "dist/"
      
  - name: "deploy"
    command: "./scripts/deploy.sh"
    environment: "production"
```

Run custom pipeline:
```bash
./scripts/aicd.sh pipeline --config config/pipeline.yaml
```

### 2. Multi-Environment Deployment

Configure environment-specific settings:
```yaml
# config/environments/development.yaml
environment:
  name: "development"
  replicas: 1
  resources:
    limits:
      memory: "512Mi"
      cpu: "500m"
    
# config/environments/production.yaml
environment:
  name: "production"
  replicas: 3
  resources:
    limits:
      memory: "2Gi"
      cpu: "2000m"
  auto_scaling:
    min_replicas: 3
    max_replicas: 10
```

### 3. Monitoring and Alerts

```bash
# Start monitoring
./scripts/aicd.sh monitor --start

# View system resources
./scripts/aicd.sh monitor --resources

# Set alert rules
./scripts/aicd.sh monitor --alert --cpu 80 --memory 90

# Generate performance report
./scripts/aicd.sh benchmark --report
```

### 4. Security Scanning

```bash
# Scan for secrets
./scripts/aicd.sh security --scan-secrets

# Scan for dependency vulnerabilities
./scripts/aicd.sh security --scan-dependencies

# Generate security report
./scripts/aicd.sh security --report --output security-report.json
```

## 🔗 Integration Guide

### GitHub Actions Integration

Create `.github/workflows/ci.yml`:
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Environment
        run: |
          chmod +x scripts/*.sh
          chmod +x tests/*.sh
          
      - name: Run Tests
        run: ./tests/run-tests.sh --verbose
        
      - name: Validate Configuration
        run: ./scripts/aicd.sh validate
        
      - name: Build Project
        if: github.ref == 'refs/heads/main'
        run: ./scripts/aicd.sh build
        
      - name: Deploy to Production
        if: github.ref == 'refs/heads/main'
        run: ./scripts/aicd.sh deploy --env production
        env:
          CFG_DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
```

### GitLab CI Integration

Create `.gitlab-ci.yml`:
```yaml
stages:
  - test
  - build
  - deploy

variables:
  CFG_PROJECT_NAME: "$CI_PROJECT_NAME"
  CFG_ENVIRONMENT: "$CI_ENVIRONMENT_NAME"

test:
  stage: test
  script:
    - chmod +x scripts/*.sh tests/*.sh
    - ./tests/run-tests.sh

build:
  stage: build
  script:
    - ./scripts/aicd.sh build
  artifacts:
    paths:
      - dist/

deploy_production:
  stage: deploy
  script:
    - ./scripts/aicd.sh deploy --env production
  environment:
    name: production
  when: manual
  only:
    - main
```

### Jenkins Integration

Create `Jenkinsfile`:
```groovy
pipeline {
    agent any
    
    environment {
        CFG_PROJECT_NAME = "${JOB_NAME}"
        CFG_ENVIRONMENT = "${ENVIRONMENT ?: 'development'}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Setup') {
            steps {
                sh 'chmod +x scripts/*.sh tests/*.sh'
            }
        }
        
        stage('Test') {
            steps {
                sh './tests/run-tests.sh'
            }
        }
        
        stage('Build') {
            steps {
                sh './scripts/aicd.sh build'
            }
        }
        
        stage('Deploy') {
            when {
                branch 'main'
            }
            steps {
                sh './scripts/aicd.sh deploy --env production'
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'dist/**/*', fingerprint: true
            sh './scripts/log-manager.sh export --build ${BUILD_NUMBER}'
        }
    }
}
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Permission Errors
```bash
# Solution: Add execute permissions
chmod +x scripts/*.sh
chmod +x tests/*.sh
```

#### 2. Configuration File Format Errors
```bash
# Validate configuration file
./scripts/aicd.sh validate --verbose

# Check YAML syntax
python -c "import yaml; yaml.safe_load(open('config/central-config.yaml'))"
```

#### 3. Log File Permission Issues
```bash
# Create log directory and set permissions
sudo mkdir -p /var/log/cicd
sudo chown $USER:$USER /var/log/cicd
chmod 755 /var/log/cicd
```

#### 4. Docker Connection Issues
```bash
# Check Docker service status
sudo systemctl status docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

### Debug Mode

Enable verbose logging:
```bash
export CFG_LOG_LEVEL="DEBUG"
./scripts/aicd.sh --verbose command
```

Generate diagnostic report:
```bash
./scripts/aicd.sh doctor --report > diagnosis.txt
```

## 💡 Best Practices

### 1. Configuration Management

- Use environment variables to override sensitive configurations
- Include configuration files in version control
- Regularly backup configuration versions

### 2. Security Practices

- Don't store secrets in configuration files
- Use secret management services
- Perform regular security scans

### 3. Performance Optimization

- Enable build caching
- Execute independent tasks in parallel
- Monitor resource usage

### 4. Monitoring and Alerts

- Set reasonable alert thresholds
- Regularly review logs
- Establish incident response procedures

## 📚 Related Resources

- [Project Homepage](https://github.com/Baozhi888/CICD-solution)
- [API Documentation](../docs/API.md)
- [Contribution Guide](../CONTRIBUTING.md)
- [Issue Tracker](https://github.com/Baozhi888/CICD-solution/issues)

---

<div align="center">
Made with ❤️ by KingJohn<br>
📧 kj331704@gmail.com
</div>