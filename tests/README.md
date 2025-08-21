# 测试指南

## 概述

本项目包含完整的单元测试和集成测试框架，用于验证 CI/CD 脚本的功能正确性。

## 测试结构

```
tests/
├── test-framework.sh      # 测试框架
├── run-tests.sh           # 测试运行器
├── unit/                  # 单元测试
│   ├── test-core.sh       # 核心库测试
│   └── test-config.sh     # 配置管理测试
└── integration/           # 集成测试
    └── (集成测试文件)
```

## 运行测试

### 本地运行所有测试

```bash
./tests/run-tests.sh
```

### 只运行单元测试

```bash
./tests/run-tests.sh --unit-only
```

### 只运行集成测试

```bash
./tests/run-tests.sh --int-only
```

### 详细输出模式

```bash
./tests/run-tests.sh --verbose
```

### 指定输出目录

```bash
./tests/run-tests.sh --output custom-output-dir
```

## 编写测试

### 创建新的测试文件

1. 在 `tests/unit/` 或 `tests/integration/` 目录下创建新的测试文件
2. 文件名应以 `test-` 开头，以 `.sh` 结尾

### 测试文件模板

```bash
#!/bin/bash

# 加载测试框架
source "$(dirname "$0")/../test-framework.sh"

# 加载被测试的模块
source "$(dirname "$0")/../../path/to/module.sh"

# 测试函数
test_feature_1() {
    echo "测试功能1..."
    
    # 使用断言函数
    assert_equals "expected" "actual" "描述"
    assert_command_succeeds "command" "命令应该成功"
    assert_file_exists "/path/to/file" "文件应该存在"
}

# 主测试函数
run_all_tests() {
    test_init
    
    # 运行测试套件
    run_test_suite "功能1测试" test_feature_1
    
    # 打印摘要
    print_test_summary
}

# 如果直接运行此脚本，执行所有测试
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_all_tests
fi
```

### 可用的断言函数

- `assert_equals expected actual [message]` - 断言两个值相等
- `assert_not_equals expected actual [message]` - 断言两个值不相等
- `assert_contains haystack needle [message]` - 断言字符串包含子串
- `assert_file_exists filepath [message]` - 断言文件存在
- `assert_command_succeeds command [message]` - 断言命令成功执行
- `assert_command_fails command [message]` - 断言命令执行失败

### 测试最佳实践

1. **测试独立性** - 每个测试应该独立运行，不依赖其他测试的状态
2. **清理测试环境** - 使用 `test_cleanup` 或在测试后清理临时文件
3. **描述性消息** - 为每个断言提供清晰的描述消息
4. **边界情况** - 测试正常情况和边界情况
5. **错误处理** - 测试错误情况的处理

## 持续集成

测试已集成到 GitHub Actions 工作流中，会在每次推送和拉取请求时自动运行。

### 工作流文件

- `templates/github/test-workflow.yml` - 测试工作流配置

## 测试覆盖率

目前测试覆盖率功能正在开发中，未来将支持：

- Shell 脚本覆盖率报告
- 覆盖率阈值检查
- 覆盖率报告上传

## 故障排除

### 常见问题

1. **权限错误**
   ```bash
   chmod +x tests/run-tests.sh
   ```

2. **路径问题**
   - 确保从项目根目录运行测试
   - 使用相对路径引用被测试的模块

3. **依赖问题**
   - 确保所有必需的工具已安装
   - 检查 Shell 脚本语法

### 调试测试

使用详细模式获取更多信息：

```bash
./tests/run-tests.sh --verbose
```

查看测试输出日志：

```bash
cat test-results/*.log
```