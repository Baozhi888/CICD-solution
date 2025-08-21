# Jenkins统一模板

## 目录结构
```
jenkins/
├── Jenkinsfile.main        # 主流水线定义
├── Jenkinsfile.pr          # PR流水线定义
├── shared/                 # 共享库
│   ├── src/
│   │   └── com/example/
│   │       ├── BuildUtils.groovy
│   │       ├── TestUtils.groovy
│   │       └── DeployUtils.groovy
│   └── vars/
│       ├── buildApp.groovy
│       ├── runTests.groovy
│       └── deployApp.groovy
└── scripts/                # 辅助脚本
    ├── docker-build.sh
    └── k8s-deploy.sh
```

## 模板特点
1. 声明式流水线语法
2. 共享库实现代码复用
3. 多分支流水线支持
4. 参数化构建配置
5. 丰富的插件生态系统集成

## 使用方法
1. 在Jenkins中配置共享库
2. 将Jenkinsfile复制到项目根目录
3. 根据项目需求调整流水线配置
4. 设置必要的凭证和环境变量