#!/usr/bin/env node
/**
 * CI/CD MCP Server
 *
 * 提供 CI/CD 自动化管理的 MCP 服务器
 * 支持通过对话式交互管理 CI/CD 流水线
 *
 * 功能:
 * - 状态查询: 查看流水线、部署状态
 * - 部署管理: 触发部署、回滚
 * - 日志分析: AI 驱动的日志分析
 * - 配置管理: 查看和比较配置
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  ListResourcesRequestSchema,
  ReadResourceRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';

// 导入工具
import { statusTool, handleStatus } from './tools/status.js';
import { deployTool, handleDeploy } from './tools/deploy.js';
import { rollbackTool, handleRollback } from './tools/rollback.js';
import { analyzeTool, handleAnalyze } from './tools/analyze.js';
import { configTool, handleConfig } from './tools/config.js';

// 导入资源
import { handleListResources, handleReadResource } from './resources/index.js';

// 服务器配置
const SERVER_NAME = 'cicd-mcp-server';
const SERVER_VERSION = '1.0.0';

// 创建 MCP 服务器
const server = new Server(
  {
    name: SERVER_NAME,
    version: SERVER_VERSION,
  },
  {
    capabilities: {
      tools: {},
      resources: {},
    },
  }
);

// 注册工具列表处理器
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      statusTool,
      deployTool,
      rollbackTool,
      analyzeTool,
      configTool,
    ],
  };
});

// 注册工具调用处理器
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'cicd_status':
        return await handleStatus(args);
      case 'cicd_deploy':
        return await handleDeploy(args);
      case 'cicd_rollback':
        return await handleRollback(args);
      case 'cicd_analyze':
        return await handleAnalyze(args);
      case 'cicd_config':
        return await handleConfig(args);
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    return {
      content: [
        {
          type: 'text',
          text: `Error: ${errorMessage}`,
        },
      ],
      isError: true,
    };
  }
});

// 注册资源列表处理器
server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return await handleListResources();
});

// 注册资源读取处理器
server.setRequestHandler(ReadResourceRequestSchema, async (request) => {
  const { uri } = request.params;
  return await handleReadResource(uri);
});

// 启动服务器
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);

  console.error(`${SERVER_NAME} v${SERVER_VERSION} started`);
}

main().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});
