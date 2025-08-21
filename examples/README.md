# 示例项目和配置

## 目录结构
```
examples/
├── nodejs-app/           # Node.js应用示例
│   ├── src/              # 源代码
│   ├── tests/            # 测试代码
│   ├── package.json      # 项目配置
│   └── Dockerfile        # Docker配置
├── python-app/           # Python应用示例
│   ├── app/              # 应用代码
│   ├── tests/            # 测试代码
│   ├── requirements.txt  # 依赖配置
│   └── Dockerfile        # Docker配置
└── deployment/           # 部署示例
    ├── k8s/              # Kubernetes部署示例
    │   ├── deployment.yaml
    │   ├── service.yaml
    │   └── ingress.yaml
    └── docker-compose/   # Docker Compose部署示例
        └── docker-compose.yml
```

## 示例说明
1. Node.js应用示例：展示如何为Node.js项目配置CI/CD
2. Python应用示例：展示如何为Python项目配置CI/CD
3. 部署示例：展示不同部署平台的配置示例

## 使用方法
1. 复制相应示例到项目目录
2. 根据项目需求调整配置文件
3. 参考示例实现项目的CI/CD配置