# CI/CD 模板库

> 企业级 CI/CD 和基础设施模板集合

本目录包含各种经过生产验证的 CI/CD 和基础设施即代码 (IaC) 模板，可帮助您快速构建现代化的部署流水线。

## 目录结构

```
templates/
├── github-actions/          # GitHub Actions 工作流模板
│   ├── ci-cd.yaml          # 完整 CI/CD 流水线
│   ├── pr-validation.yaml  # PR 验证工作流
│   └── release.yaml        # 发布工作流
├── docker/                  # Docker 相关模板
│   ├── Dockerfile.node     # Node.js 多阶段构建
│   ├── Dockerfile.python   # Python 多阶段构建
│   ├── docker-compose.dev.yaml   # 开发环境
│   └── docker-compose.prod.yaml  # 生产环境
├── kubernetes/              # Kubernetes 部署模板
│   ├── deployment.yaml     # 完整部署配置
│   └── ingress.yaml        # Ingress 和网络策略
└── terraform/               # Terraform IaC 模板
    ├── main.tf             # AWS 基础设施
    └── env/                # 环境变量文件
        └── production.tfvars.example
```

## 快速开始

### GitHub Actions

1. 复制所需的工作流文件到项目的 `.github/workflows/` 目录
2. 根据项目需要修改配置
3. 配置 GitHub Secrets

```bash
# 复制 CI/CD 工作流
cp templates/github-actions/ci-cd.yaml .github/workflows/

# 复制 PR 验证工作流
cp templates/github-actions/pr-validation.yaml .github/workflows/
```

所需 Secrets:
- `SNYK_TOKEN` - Snyk 安全扫描 Token
- `CODECOV_TOKEN` - Codecov 覆盖率上传 Token
- `SLACK_WEBHOOK` - Slack 通知 Webhook
- `NPM_TOKEN` - npm 发布 Token (可选)

### Docker

1. 复制 Dockerfile 到项目根目录
2. 根据项目类型修改配置
3. 使用 docker-compose 启动服务

```bash
# 开发环境
docker compose -f docker-compose.dev.yaml up -d

# 生产环境
docker compose -f docker-compose.prod.yaml up -d
```

### Kubernetes

1. 将模板文件复制到项目的 `k8s/` 或 `deploy/` 目录
2. 使用 Helm 或 Kustomize 管理环境差异
3. 使用 kubectl 部署

```bash
# 直接部署
kubectl apply -f k8s/

# 或使用 Kustomize
kubectl apply -k k8s/overlays/production/
```

### Terraform

1. 复制 Terraform 文件到项目的 `infrastructure/` 目录
2. 创建后端配置（S3 + DynamoDB）
3. 创建环境变量文件

```bash
# 初始化
terraform init

# 规划
terraform plan -var-file="env/production.tfvars"

# 应用
terraform apply -var-file="env/production.tfvars"
```

## 模板特性

### GitHub Actions 模板

| 特性 | ci-cd.yaml | pr-validation.yaml | release.yaml |
|------|------------|-------------------|--------------|
| 代码检查 | ✅ | ✅ | ✅ |
| 安全扫描 | ✅ | - | - |
| 单元测试 | ✅ | ✅ | ✅ |
| 构建验证 | ✅ | ✅ | ✅ |
| Docker 构建 | ✅ | - | ✅ |
| 自动部署 | ✅ | - | ✅ |
| 发布管理 | - | - | ✅ |
| PR 标签 | - | ✅ | - |

### Docker 模板

- **多阶段构建** - 最小化镜像体积
- **非 root 用户** - 提升安全性
- **健康检查** - 容器健康监控
- **dumb-init** - 正确处理信号
- **缓存优化** - 加速构建

### Kubernetes 模板

- **滚动更新** - 零停机部署
- **自动扩缩** - HPA 配置
- **资源限制** - CPU/内存管理
- **健康探针** - 存活/就绪检查
- **网络策略** - Pod 间通信控制
- **安全上下文** - 容器安全加固

### Terraform 模板

- **VPC 网络** - 公有/私有子网
- **EKS 集群** - 托管 Kubernetes
- **RDS 数据库** - PostgreSQL 高可用
- **ElastiCache** - Redis 缓存
- **KMS 加密** - 数据加密
- **IAM 角色** - 最小权限原则

## 自定义

### 环境变量

所有模板都支持通过环境变量进行配置：

```bash
# 项目名称
PROJECT_NAME=myapp

# 环境
ENVIRONMENT=production

# 镜像仓库
REGISTRY=ghcr.io
IMAGE_NAME=org/app

# 副本数
REPLICAS=3
```

### Helm 值文件

Kubernetes 模板可以与 Helm 一起使用：

```yaml
# values.yaml
name: myapp
namespace: production
replicas: 3
image:
  repository: ghcr.io/org/app
  tag: v1.0.0
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## 最佳实践

### 安全

- ✅ 使用 GitHub Secrets 存储敏感信息
- ✅ 启用依赖漏洞扫描
- ✅ 使用非 root 用户运行容器
- ✅ 启用 KMS 加密
- ✅ 配置网络策略限制流量

### 可靠性

- ✅ 配置健康检查
- ✅ 设置资源限制
- ✅ 使用 PodDisruptionBudget
- ✅ 启用多可用区部署
- ✅ 配置自动备份

### 性能

- ✅ 使用多阶段构建减小镜像体积
- ✅ 配置构建缓存
- ✅ 启用 HPA 自动扩缩
- ✅ 使用 CDN 加速静态资源

## 许可证

MIT License
