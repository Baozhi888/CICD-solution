# GitLab CI 统一模板

## 配置结构
```
.gitlab-ci.yml        # 主配置文件
gitlab/
├── jobs/             # 作业定义
│   ├── build.yml     # 构建作业
│   ├── test.yml      # 测试作业
│   └── deploy.yml    # 部署作业
└── templates/        # 模板定义
    ├── docker.yml    # Docker模板
    └── k8s.yml       # Kubernetes模板
```

## 模板特点
1. 使用YAML锚点减少重复配置
2. 基于rules:changes的智能触发
3. 多环境部署支持
4. 安全扫描集成
5. 自动化测试矩阵

## 使用方法
1. 复制此目录到项目根目录
2. 根据项目需求调整.gitlab-ci.yml
3. 设置必要的CI/CD变量和密钥