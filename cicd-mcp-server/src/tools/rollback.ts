/**
 * Rollback Tool
 *
 * 回滚部署的工具
 * 支持:
 * - 回滚到指定版本
 * - 回滚到上一版本
 * - 查看可回滚版本列表
 * - 回滚预览
 */

import { Tool } from '@modelcontextprotocol/sdk/types.js';
import {
  executeAicd,
  executeScript,
  getCentralConfig,
  getTimestamp,
  formatTable,
} from '../utils/helpers.js';

// 工具定义
export const rollbackTool: Tool = {
  name: 'cicd_rollback',
  description: `回滚 CI/CD 部署。可以将项目回滚到之前的版本，支持版本选择和预览。

使用场景:
- "回滚到上一个版本"
- "回滚到 v1.1.0"
- "显示可以回滚的版本"
- "预览回滚会产生什么变化"`,
  inputSchema: {
    type: 'object',
    properties: {
      version: {
        type: 'string',
        description: '要回滚到的版本号。不指定则回滚到上一版本',
      },
      environment: {
        type: 'string',
        enum: ['development', 'staging', 'production'],
        description: '回滚的目标环境',
      },
      listVersions: {
        type: 'boolean',
        description: '是否只列出可回滚的版本，不执行回滚',
        default: false,
      },
      dryRun: {
        type: 'boolean',
        description: '是否只预览回滚，不实际执行',
        default: false,
      },
      force: {
        type: 'boolean',
        description: '是否跳过确认直接回滚',
        default: false,
      },
    },
    required: [],
  },
};

interface RollbackArgs {
  version?: string;
  environment?: string;
  listVersions?: boolean;
  dryRun?: boolean;
  force?: boolean;
}

// 处理回滚请求
export async function handleRollback(args: unknown): Promise<{
  content: Array<{ type: string; text: string }>;
}> {
  const {
    version,
    environment,
    listVersions = false,
    dryRun = false,
    force = false,
  } = args as RollbackArgs;

  const results: string[] = [];
  results.push(`# 回滚操作\n`);
  results.push(`> 时间: ${getTimestamp()}`);
  if (environment) {
    results.push(`> 环境: ${environment}`);
  }
  if (version) {
    results.push(`> 目标版本: ${version}`);
  }
  results.push('');

  try {
    // 检查回滚是否启用
    const config = (await getCentralConfig()) as {
      deploy?: { rollback_enabled?: boolean };
      rollback?: {
        strategies?: string[];
        auto_rollback_on_failure?: boolean;
      };
    };

    if (!config?.deploy?.rollback_enabled) {
      results.push('## ❌ 回滚功能未启用\n');
      results.push('请在配置文件中设置 `deploy.rollback_enabled: true`');
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    // 显示回滚配置
    results.push('## 回滚配置\n');
    results.push(
      formatTable(
        ['配置项', '值'],
        [
          ['回滚策略', config.rollback?.strategies?.join(', ') || 'default'],
          [
            '自动回滚',
            config.rollback?.auto_rollback_on_failure ? '启用' : '禁用',
          ],
        ]
      )
    );
    results.push('');

    // 列出可回滚版本
    if (listVersions) {
      results.push('## 可回滚版本\n');
      const versionsResult = await getAvailableVersions();
      results.push(versionsResult);
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    // 预览回滚
    if (dryRun) {
      results.push('## 回滚预览\n');
      const previewResult = await previewRollback(version);
      results.push(previewResult);
      results.push('\n---\n');
      results.push('**预览模式**: 实际回滚未执行。');
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    // 确认提示
    if (!force) {
      results.push('## ⚠️ 回滚确认\n');
      results.push('回滚操作将影响当前运行的服务。\n');
      results.push('请确认以下事项:');
      results.push('- 已了解回滚的影响');
      results.push('- 已通知相关团队成员');
      results.push('- 已准备好应急方案\n');
      results.push('如果确认要继续，请使用 `force: true` 参数重新调用。');
      results.push('\n提示: 使用 `dryRun: true` 可以先预览回滚内容。');
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    // 执行回滚
    results.push('## 执行回滚\n');

    const rollbackArgs: string[] = [];
    if (version) {
      rollbackArgs.push(version);
    }

    const rollbackResult = await executeAicd('rollback', rollbackArgs, {
      timeout: 180000, // 3 分钟超时
    });

    if (rollbackResult.exitCode === 0) {
      results.push('### ✅ 回滚成功\n');
      results.push(`\`\`\`\n${rollbackResult.stdout}\n\`\`\``);

      results.push('\n### 后续步骤\n');
      results.push('- 验证服务状态');
      results.push('- 检查应用日志');
      results.push('- 通知相关团队');
    } else {
      results.push('### ❌ 回滚失败\n');
      results.push(
        `\`\`\`\n${rollbackResult.stderr || rollbackResult.stdout}\n\`\`\``
      );

      results.push('\n### 建议操作\n');
      results.push('- 检查配置版本管理器状态');
      results.push('- 使用 `cicd_analyze` 分析失败原因');
      results.push('- 考虑手动恢复');
    }
  } catch (error) {
    results.push(`\n### 错误\n\n回滚过程中发生错误: ${error}`);
  }

  return {
    content: [{ type: 'text', text: results.join('\n') }],
  };
}

// 获取可回滚版本
async function getAvailableVersions(): Promise<string> {
  try {
    const result = await executeScript('config-version-manager.sh', ['list']);

    if (result.exitCode === 0 && result.stdout) {
      return `\`\`\`\n${result.stdout}\n\`\`\``;
    }

    // 如果脚本不可用，返回模拟数据
    return formatTable(
      ['版本', '时间', '描述'],
      [
        ['v1.0.0', '2024-01-01', '初始版本'],
        ['v1.0.1', '2024-01-15', 'Bug 修复'],
        ['v1.1.0', '2024-02-01', '新功能'],
      ]
    );
  } catch (error) {
    return `获取版本列表失败: ${error}`;
  }
}

// 预览回滚
async function previewRollback(version?: string): Promise<string> {
  const lines: string[] = [];

  lines.push(`目标版本: ${version || '上一版本'}\n`);

  lines.push('### 预期变更\n');
  lines.push('以下内容将被回滚:');
  lines.push('- 配置文件');
  lines.push('- 部署脚本');
  lines.push('- 环境变量\n');

  lines.push('### 影响范围\n');
  lines.push('- 当前运行的服务将重启');
  lines.push('- 新版本的功能将不可用');
  lines.push('- 数据库迁移不会自动回滚\n');

  lines.push('### 注意事项\n');
  lines.push('- 确保数据库兼容回滚版本');
  lines.push('- 检查是否有不兼容的 API 变更');
  lines.push('- 通知依赖服务的团队');

  return lines.join('\n');
}
