# 贡献指南

感谢您对 CI/CD 解决方案项目的关注！我们欢迎任何形式的贡献。

## 🤝 如何贡献

### 报告问题

如果您发现了 bug 或有功能建议，请：

1. 先检查 [Issues](https://github.com/your-username/cicd-solution/issues) 确保问题未被报告
2. 创建新 Issue，使用适当的模板：
   - 🐛 Bug 报告
   - ✨ 功能请求
   - 📚 文档改进
   - ❓ 问题咨询

### 提交代码

#### 开发环境设置

```bash
# 1. Fork 并克隆项目
git clone https://github.com/your-username/cicd-solution.git
cd cicd-solution

# 2. 添加上游仓库
git remote add upstream https://github.com/original-username/cicd-solution.git

# 3. 创建功能分支
git checkout -b feature/your-feature-name
```

#### 代码规范

- **Shell 脚本**：
  - 使用 `shellcheck` 检查代码质量
  - 遵循 [Shell Style Guide](https://google.github.io/styleguide/shell.xml)
  - 添加适当的注释

- **测试要求**：
  - 新功能必须包含测试
  - 保持测试覆盖率
  - 运行 `./tests/run-tests.sh` 确保所有测试通过

#### 提交规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
feat: 添加新功能
fix: 修复 bug
docs: 文档更新
style: 代码格式化
refactor: 代码重构
test: 测试相关
chore: 构建或辅助工具变动
```

示例：
```bash
git commit -m "feat: 添加 Docker 部署支持

- 新增 docker-compose.yml 配置
- 添加容器化部署脚本
- 更新相关文档"
```

#### Pull Request 流程

1. 确保代码通过所有测试
2. 更新相关文档
3. 提交 PR 到 `main` 分支
4. 填写 PR 模板
5. 等待代码审查

## 🏷️ 标签说明

| 标签 | 说明 |
|------|------|
| `bug` | 错误修复 |
| `enhancement` | 功能增强 |
| `documentation` | 文档相关 |
| `good first issue` | 适合新手 |
| `help wanted` | 需要帮助 |
| `priority: high` | 高优先级 |

## 📝 文档贡献

文档改进同样重要！您可以：

- 修复拼写错误
- 添加使用示例
- 翻译文档
- 改进说明清晰度

## 🎯 社区行为准则

请遵循以下原则：

- 保持友善和尊重
- 提供建设性反馈
- 专注于技术讨论
- 欢迎新手参与

## 📞 联系方式

- GitHub Issues: 技术问题和功能请求
- GitHub Discussions: 一般讨论和想法
- Email: kj331704@gmail.com (私人咨询)

## 🙏 致谢

所有贡献者都将被列入 [贡献者列表](CONTRIBUTORS.md)。

---

**Happy Coding!** 🎉