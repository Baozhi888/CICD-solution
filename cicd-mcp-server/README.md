# CI/CD MCP Server

MCP (Model Context Protocol) Server for CI/CD automation - enables conversational CI/CD management.

CI/CD 自动化的 MCP 服务器 - 支持对话式 CI/CD 管理。

## Features | 功能特性

### Tools | 工具

| Tool | Description |
|------|-------------|
| `cicd_status` | 查看 CI/CD 系统状态 (项目、流水线、部署、健康) |
| `cicd_deploy` | 触发部署到指定环境，支持版本控制和预检查 |
| `cicd_rollback` | 回滚部署到之前版本，支持版本选择和预览 |
| `cicd_analyze` | AI 分析日志、配置、部署、性能、安全 |
| `cicd_config` | 管理配置：查看、比较、验证、合并 |

### Resources | 资源

| Resource | Description |
|----------|-------------|
| `cicd://config/central` | 中央配置文件 |
| `cicd://config/ai` | AI 功能配置 |
| `cicd://config/environment/{env}` | 环境特定配置 |
| `cicd://pipeline/build` | 构建流水线配置 |
| `cicd://pipeline/test` | 测试流水线配置 |
| `cicd://pipeline/deploy` | 部署流水线配置 |
| `cicd://templates/github-actions` | GitHub Actions 模板 |
| `cicd://templates/docker` | Docker 模板 |
| `cicd://templates/kubernetes` | Kubernetes 模板 |
| `cicd://scripts/list` | 可用脚本列表 |

## Installation | 安装

```bash
cd cicd-mcp-server
npm install
npm run build
```

## Usage | 使用

### With Claude Desktop | 配合 Claude Desktop

Add to your Claude Desktop config (`~/Library/Application Support/Claude/claude_desktop_config.json` on macOS):

```json
{
  "mcpServers": {
    "cicd": {
      "command": "node",
      "args": ["/path/to/cicd-mcp-server/dist/index.js"],
      "env": {
        "CICD_PROJECT_ROOT": "/path/to/your/project"
      }
    }
  }
}
```

### Development | 开发

```bash
# 开发模式（热重载）
npm run dev

# 构建
npm run build

# 代码检查
npm run lint

# 测试
npm test
```

## Example Conversations | 对话示例

```
User: 帮我部署 v1.2.0 到 staging
Assistant: [使用 cicd_deploy 工具] 正在部署 v1.2.0 到 staging 环境...

User: 分析最近的部署失败
Assistant: [使用 cicd_analyze 工具] 检测到以下问题...

User: 比较 production 和 staging 的配置差异
Assistant: [使用 cicd_config 工具] 配置差异如下...

User: 回滚到上一个版本
Assistant: [使用 cicd_rollback 工具] 正在回滚...
```

## Environment Variables | 环境变量

| Variable | Description | Default |
|----------|-------------|---------|
| `CICD_PROJECT_ROOT` | 项目根目录 | `process.cwd()` |
| `AICD_MCP_MODE` | MCP 模式标识 | `true` (auto) |

## Architecture | 架构

```
cicd-mcp-server/
├── src/
│   ├── index.ts          # MCP Server 入口
│   ├── tools/            # MCP Tools
│   │   ├── status.ts     # 状态查询
│   │   ├── deploy.ts     # 部署管理
│   │   ├── rollback.ts   # 回滚操作
│   │   ├── analyze.ts    # 智能分析
│   │   └── config.ts     # 配置管理
│   ├── resources/        # MCP Resources
│   │   └── index.ts      # 资源处理器
│   └── utils/            # 工具函数
│       └── helpers.ts    # 通用辅助函数
├── package.json
├── tsconfig.json
└── README.md
```

## Integration | 集成

This MCP Server integrates with:
- `scripts/aicd.sh` - 主 CLI 工具
- `scripts/ai-supervisor.sh` - AI 监督工具
- `lib/ai/` - AI 功能模块
- `config/` - 配置文件

## License | 许可证

MIT
