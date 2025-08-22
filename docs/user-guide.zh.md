# 📖 CICD-solution 使用指南

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

本指南将帮助您快速上手并充分利用 CICD-solution 的功能。

[**English Version**](user-guide.en.md) | **中文**

## 📋 目录

- [快速开始](#快速开始)
- [系统要求](#系统要求)
- [安装与配置](#安装与配置)
- [基本使用](#基本使用)
- [高级功能](#高级功能)
- [集成指南](#集成指南)
- [故障排除](#故障排除)
- [最佳实践](#最佳实践)

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/Baozhi888/CICD-solution.git
cd CICD-solution
```

### 2. 设置执行权限
```bash
# 给所有脚本添加执行权限
chmod +x scripts/*.sh
chmod +x tests/*.sh
```

### 3. 运行测试验证
```bash
./tests/run-tests.sh
```

## 🖥️ 系统要求

- **操作系统**: Linux, macOS, Windows (WSL)
- **Shell**: Bash 4.0+
- **内存**: 最小 512MB
- **存储**: 最小 100MB
- **网络**: 可选（用于下载依赖）

## 📦 安装与配置

### 基础配置

1. **编辑中央配置文件**
   ```bash
   nano config/central-config.yaml
   ```

2. **设置项目信息**
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

3. **配置构建和部署**
   ```yaml
   ci_cd:
     build_command: "npm run build"
     test_command: "npm test"
     deploy_command: "./scripts/deploy.sh"
   ```

### 环境变量配置

创建 `.env` 文件：
```bash
# 项目配置
export CFG_PROJECT_NAME="my-project"
export CFG_ENVIRONMENT="development"

# 日志配置
export CFG_LOG_LEVEL="INFO"
export CFG_LOG_DIR="/var/log/cicd"

# 部署配置
export CFG_DEPLOY_TARGET="kubernetes"
export CFG_KUBE_CONTEXT="my-cluster"
```

## 🔧 基本使用

### 使用 aicd 命令行工具

```bash
# 显示帮助信息
./scripts/aicd.sh --help

# 初始化项目
./scripts/aicd.sh init

# 验证配置
./scripts/aicd.sh validate

# 运行构建
./scripts/aicd.sh build

# 运行测试
./scripts/aicd.sh test

# 部署到指定环境
./scripts/aicd.sh deploy --env production

# 回滚部署
./scripts/aicd.sh rollback --version v1.0.0
```

### 日志管理

```bash
# 启动日志管理器
./scripts/log-manager.sh start

# 查看日志状态
./scripts/log-manager.sh status

# 清理旧日志（保留最近7天）
./scripts/log-manager.sh cleanup --days 7

# 查看实时日志
./scripts/log-manager.sh tail --follow

# 导出日志
./scripts/log-manager.sh export --format json --output logs.json
```

### 配置版本管理

```bash
# 创建配置版本
./scripts/config-version-manager.sh create "添加新功能配置"

# 查看版本历史
./scripts/config-version-manager.sh history

# 比较版本差异
./scripts/config-version-manager.sh diff v1.0.0 v1.1.0

# 回滚到指定版本
./scripts/config-version-manager.sh rollback v1.0.0

# 标记版本为稳定
./scripts/config-version-manager.sh tag v1.0.0 stable
```

## 🚀 高级功能

### 1. 自定义构建流水线

创建自定义流水线配置 `config/pipeline.yaml`：
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

运行自定义流水线：
```bash
./scripts/aicd.sh pipeline --config config/pipeline.yaml
```

### 2. 多环境部署

配置环境特定的设置：
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

### 3. 监控和告警

```bash
# 启动监控
./scripts/aicd.sh monitor --start

# 查看系统资源
./scripts/aicd.sh monitor --resources

# 设置告警规则
./scripts/aicd.sh monitor --alert --cpu 80 --memory 90

# 生成性能报告
./scripts/aicd.sh benchmark --report
```

### 4. 安全扫描

```bash
# 扫描密钥
./scripts/aicd.sh security --scan-secrets

# 扫描依赖漏洞
./scripts/aicd.sh security --scan-dependencies

# 生成安全报告
./scripts/aicd.sh security --report --output security-report.json
```

## 🔗 集成指南

### GitHub Actions 集成

创建 `.github/workflows/ci.yml`：
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

### GitLab CI 集成

创建 `.gitlab-ci.yml`：
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

### Jenkins 集成

创建 `Jenkinsfile`：
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

## 🐛 故障排除

### 常见问题

#### 1. 权限错误
```bash
# 解决方案：添加执行权限
chmod +x scripts/*.sh
chmod +x tests/*.sh
```

#### 2. 配置文件格式错误
```bash
# 验证配置文件
./scripts/aicd.sh validate --verbose

# 检查 YAML 语法
python -c "import yaml; yaml.safe_load(open('config/central-config.yaml'))"
```

#### 3. 日志文件权限问题
```bash
# 创建日志目录并设置权限
sudo mkdir -p /var/log/cicd
sudo chown $USER:$USER /var/log/cicd
chmod 755 /var/log/cicd
```

#### 4. Docker 连接问题
```bash
# 检查 Docker 服务状态
sudo systemctl status docker

# 将用户添加到 docker 组
sudo usermod -aG docker $USER
newgrp docker
```

### 调试模式

启用详细日志：
```bash
export CFG_LOG_LEVEL="DEBUG"
./scripts/aicd.sh --verbose command
```

生成诊断报告：
```bash
./scripts/aicd.sh doctor --report > diagnosis.txt
```

## 💡 最佳实践

### 1. 配置管理

- 使用环境变量覆盖敏感配置
- 将配置文件纳入版本控制
- 定期备份配置版本

### 2. 安全实践

- 不要在配置文件中存储密钥
- 使用密钥管理服务
- 定期进行安全扫描

### 3. 性能优化

- 启用构建缓存
- 并行执行独立任务
- 监控资源使用情况

### 4. 监控和告警

- 设置合理的告警阈值
- 定期审查日志
- 建立故障响应流程

## 📚 相关资源

- [项目主页](https://github.com/Baozhi888/CICD-solution)
- [API 文档](../docs/API.md)
- [贡献指南](../CONTRIBUTING.md)
- [问题反馈](https://github.com/Baozhi888/CICD-solution/issues)

---

<div align="center">
Made with ❤️ by KingJohn<br>
📧 kj331704@gmail.com
</div>