# 跨平台共享组件

## 目录结构
```
shared/
├── scripts/              # 通用脚本
│   ├── build.sh          # 构建脚本
│   ├── test.sh           # 测试脚本
│   ├── deploy.sh         # 部署脚本
│   └── rollback.sh       # 回滚脚本
├── configs/              # 配置模板
│   ├── docker-compose.yml.template
│   ├── k8s-deployment.yaml.template
│   └── nginx.conf.template
└── libraries/            # 脚本库
    ├── logging.sh        # 日志库
    ├── utils.sh          # 工具库
    └── validation.sh     # 验证库
```

## 组件说明
1. 通用脚本：可在不同CI/CD平台复用的shell脚本
2. 配置模板：环境配置和部署配置的模板文件
3. 脚本库：提供通用功能的脚本库文件

## 使用方法
1. 根据具体平台要求调整脚本路径引用
2. 使用环境变量控制脚本行为
3. 遵循脚本中的使用说明和参数要求