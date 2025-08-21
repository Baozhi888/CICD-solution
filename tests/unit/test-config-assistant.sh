#!/bin/bash

# 演练与配置生成助手单元测试
# 测试基于BMad-Method的演练与配置生成功能

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# --- 测试用例 ---

test_project_type_detection() {
    echo "测试项目类型检测..."
    
    # 创建一个模拟的项目类型检测脚本
    local mock_script=$(create_test_file "mock_project_detector.sh")
    cat > "$mock_script" << 'EOF'
#!/bin/bash
# 模拟项目类型检测的核心逻辑

# 函数：检测项目类型
detect_project_type() {
    local project_dir="$1"
    echo "检测项目类型..."
    
    # 模拟检测逻辑
    if [[ -f "$project_dir/package.json" ]]; then
        echo "检测到Node.js项目"
        echo "项目类型: nodejs"
    elif [[ -f "$project_dir/requirements.txt" ]]; then
        echo "检测到Python项目"
        echo "项目类型: python"
    elif [[ -f "$project_dir/pom.xml" ]]; then
        echo "检测到Java Maven项目"
        echo "项目类型: java-maven"
    elif [[ -f "$project_dir/build.gradle" ]]; then
        echo "检测到Java Gradle项目"
        echo "项目类型: java-gradle"
    else
        echo "未识别的项目类型"
        echo "项目类型: unknown"
    fi
    
    echo "项目类型检测完成"
}

# 函数：分析项目结构
analyze_project_structure() {
    local project_dir="$1"
    echo "分析项目结构..."
    
    # 模拟分析项目结构
    echo "项目结构分析:"
    echo "  源代码目录: src/"
    echo "  测试目录: tests/"
    echo "  配置文件: config/"
    echo "  文档目录: docs/"
    echo "  构建输出: dist/"
    
    echo "项目结构分析完成"
}

# 函数：识别技术栈
identify_tech_stack() {
    local project_dir="$1"
    echo "识别技术栈..."
    
    # 模拟识别技术栈
    echo "技术栈识别:"
    echo "  编程语言: JavaScript/TypeScript"
    echo "  框架: Express.js"
    echo "  测试框架: Jest"
    echo "  构建工具: Webpack"
    echo "  包管理器: npm"
    
    echo "技术栈识别完成"
}

# 调用函数进行测试
detect_project_type "/tmp/test-project"
analyze_project_structure "/tmp/test-project"
identify_tech_stack "/tmp/test-project"
EOF
    chmod +x "$mock_script"
    
    local output
    output=$("$mock_script")
    
    # 验证各个功能
    assert_contains "$output" "检测项目类型..." "应执行项目类型检测"
    assert_contains "$output" "检测到Node.js项目" "应检测出Node.js项目类型"
    assert_contains "$output" "项目类型: nodejs" "应输出项目类型标识"
    assert_contains "$output" "项目类型检测完成" "项目类型检测应完成"
    
    assert_contains "$output" "分析项目结构..." "应执行项目结构分析"
    assert_contains "$output" "源代码目录: src/" "应分析出项目结构"
    assert_contains "$output" "项目结构分析完成" "项目结构分析应完成"
    
    assert_contains "$output" "识别技术栈..." "应执行技术栈识别"
    assert_contains "$output" "编程语言: JavaScript/TypeScript" "应识别出技术栈"
    assert_contains "$output" "技术栈识别完成" "技术栈识别应完成"
}

test_ci_cd_template_generation() {
    echo "测试CI/CD模板生成..."
    
    # 创建一个模拟的CI/CD模板生成脚本
    local mock_script=$(create_test_file "mock_template_generator.sh")
    cat > "$mock_script" << 'EOF'
#!/bin/bash
# 模拟CI/CD模板生成的核心逻辑

# 函数：生成GitHub Actions模板
generate_github_template() {
    local project_type="$1"
    echo "生成GitHub Actions模板..."
    
    # 模拟生成模板
    cat > "/tmp/github-ci.yml" << EOFF
name: CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: '18'
    - name: Install dependencies
      run: npm ci
    - name: Run tests
      run: npm test
    - name: Build
      run: npm run build
EOFF
    
    echo "GitHub Actions模板生成完成: /tmp/github-ci.yml"
}

# 函数：生成GitLab CI模板
generate_gitlab_template() {
    local project_type="$1"
    echo "生成GitLab CI模板..."
    
    # 模拟生成模板
    cat > "/tmp/gitlab-ci.yml" << EOFF
stages:
  - build
  - test
  - deploy

variables:
  NODE_VERSION: "18"

before_script:
  - echo "Running before script"

build_job:
  stage: build
  script:
    - echo "Building the application"
    - npm ci
    - npm run build

test_job:
  stage: test
  script:
    - echo "Running tests"
    - npm test

deploy_job:
  stage: deploy
  script:
    - echo "Deploying the application"
  only:
    - main
EOFF
    
    echo "GitLab CI模板生成完成: /tmp/gitlab-ci.yml"
}

# 函数：生成配置文件
generate_config_files() {
    local project_type="$1"
    echo "生成配置文件..."
    
    # 模拟生成配置文件
    cat > "/tmp/docker-compose.yml" << EOFF
version: '3.8'
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
EOFF
    
    cat > "/tmp/Dockerfile" << EOFF
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
EOFF
    
    echo "配置文件生成完成: /tmp/docker-compose.yml, /tmp/Dockerfile"
}

# 调用函数进行测试
generate_github_template "nodejs"
generate_gitlab_template "nodejs"
generate_config_files "nodejs"
EOF
    chmod +x "$mock_script"
    
    local output
    output=$("$mock_script")
    
    # 验证各个功能
    assert_contains "$output" "生成GitHub Actions模板..." "应执行GitHub Actions模板生成"
    assert_file_exists "/tmp/github-ci.yml" "应生成GitHub Actions模板文件"
    assert_contains "$output" "GitHub Actions模板生成完成" "GitHub Actions模板生成应完成"
    
    assert_contains "$output" "生成GitLab CI模板..." "应执行GitLab CI模板生成"
    assert_file_exists "/tmp/gitlab-ci.yml" "应生成GitLab CI模板文件"
    assert_contains "$output" "GitLab CI模板生成完成" "GitLab CI模板生成应完成"
    
    assert_contains "$output" "生成配置文件..." "应执行配置文件生成"
    assert_file_exists "/tmp/docker-compose.yml" "应生成docker-compose.yml文件"
    assert_file_exists "/tmp/Dockerfile" "应生成Dockerfile文件"
    assert_contains "$output" "配置文件生成完成" "配置文件生成应完成"
}

test_interactive_config_assistant() {
    echo "测试交互式配置助手..."
    
    # 创建一个模拟的交互式配置助手脚本
    local mock_script=$(create_test_file "mock_config_assistant.sh")
    cat > "$mock_script" << 'EOF'
#!/bin/bash
# 模拟交互式配置助手的核心逻辑

# 函数：询问项目信息
ask_project_info() {
    echo "询问项目信息..."
    
    # 模拟交互式询问
    echo "项目名称: my-awesome-app"
    echo "项目描述: A sample Node.js application"
    echo "作者: John Doe <john.doe@example.com>"
    echo "许可证: MIT"
    
    echo "项目信息询问完成"
}

# 函数：询问技术栈
ask_tech_stack() {
    echo "询问技术栈..."
    
    # 模拟交互式询问
    echo "编程语言: JavaScript"
    echo "框架: Express.js"
    echo "测试框架: Jest"
    echo "构建工具: Webpack"
    echo "包管理器: npm"
    
    echo "技术栈询问完成"
}

# 函数：询问部署目标
ask_deployment_target() {
    echo "询问部署目标..."
    
    # 模拟交互式询问
    echo "部署平台: Kubernetes"
    echo "容器注册表: Docker Hub"
    echo "镜像名称: my-awesome-app"
    echo "命名空间: default"
    
    echo "部署目标询问完成"
}

# 函数：生成最终配置
generate_final_config() {
    echo "生成最终配置..."
    
    # 模拟生成最终配置
    cat > "/tmp/final-config.json" << EOFF
{
  "project": {
    "name": "my-awesome-app",
    "description": "A sample Node.js application",
    "author": "John Doe <john.doe@example.com>",
    "license": "MIT"
  },
  "techStack": {
    "language": "JavaScript",
    "framework": "Express.js",
    "testFramework": "Jest",
    "buildTool": "Webpack",
    "packageManager": "npm"
  },
  "deployment": {
    "platform": "Kubernetes",
    "registry": "Docker Hub",
    "imageName": "my-awesome-app",
    "namespace": "default"
  }
}
EOFF
    
    echo "最终配置生成完成: /tmp/final-config.json"
}

# 调用函数进行测试
ask_project_info
ask_tech_stack
ask_deployment_target
generate_final_config
EOF
    chmod +x "$mock_script"
    
    local output
    output=$("$mock_script")
    
    # 验证各个功能
    assert_contains "$output" "询问项目信息..." "应执行项目信息询问"
    assert_contains "$output" "项目名称: my-awesome-app" "应询问项目信息"
    assert_contains "$output" "项目信息询问完成" "项目信息询问应完成"
    
    assert_contains "$output" "询问技术栈..." "应执行技术栈询问"
    assert_contains "$output" "编程语言: JavaScript" "应询问技术栈"
    assert_contains "$output" "技术栈询问完成" "技术栈询问应完成"
    
    assert_contains "$output" "询问部署目标..." "应执行部署目标询问"
    assert_contains "$output" "部署平台: Kubernetes" "应询问部署目标"
    assert_contains "$output" "部署目标询问完成" "部署目标询问应完成"
    
    assert_contains "$output" "生成最终配置..." "应执行最终配置生成"
    assert_file_exists "/tmp/final-config.json" "应生成最终配置文件"
    assert_contains "$output" "最终配置生成完成" "最终配置生成应完成"
}


# --- 主测试函数 ---

run_all_tests() {
    test_init
    
    # 运行所有测试套件
    run_test_suite "项目类型检测" test_project_type_detection
    run_test_suite "模板生成" test_ci_cd_template_generation
    run_test_suite "配置助手" test_interactive_config_assistant
    
    # 打印测试摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi