/**
 * Config Tool
 *
 * 配置管理工具
 * 支持:
 * - 查看配置
 * - 比较配置
 * - 验证配置
 * - 合并配置
 */

import { Tool } from '@modelcontextprotocol/sdk/types.js';
import {
  executeScript,
  getCentralConfig,
  readYamlConfig,
  getTimestamp,
  formatYamlBlock,
  formatTable,
} from '../utils/helpers.js';

// 工具定义
export const configTool: Tool = {
  name: 'cicd_config',
  description: `管理 CI/CD 配置。查看、比较、验证和合并配置文件。

使用场景:
- "显示当前配置"
- "比较 staging 和 production 的配置差异"
- "验证配置文件是否正确"
- "合并环境配置"`,
  inputSchema: {
    type: 'object',
    properties: {
      action: {
        type: 'string',
        enum: ['show', 'compare', 'validate', 'merge', 'diff'],
        description:
          '操作类型: show(显示), compare(比较), validate(验证), merge(合并), diff(差异)',
        default: 'show',
      },
      config: {
        type: 'string',
        description: '配置文件路径或配置节点路径 (如: project.name)',
      },
      env1: {
        type: 'string',
        description: '第一个环境 (用于比较)',
      },
      env2: {
        type: 'string',
        description: '第二个环境 (用于比较)',
      },
      format: {
        type: 'string',
        enum: ['yaml', 'json', 'table'],
        description: '输出格式',
        default: 'yaml',
      },
    },
    required: ['action'],
  },
};

type ConfigAction = 'show' | 'compare' | 'validate' | 'merge' | 'diff';

interface ConfigArgs {
  action: ConfigAction;
  config?: string;
  env1?: string;
  env2?: string;
  format?: 'yaml' | 'json' | 'table';
}

// 处理配置请求
export async function handleConfig(args: unknown): Promise<{
  content: Array<{ type: string; text: string }>;
}> {
  const {
    action,
    config,
    env1,
    env2,
    format = 'yaml',
  } = args as ConfigArgs;

  const results: string[] = [];
  results.push(`# 配置管理\n`);
  results.push(`> 时间: ${getTimestamp()}`);
  results.push(`> 操作: ${action}\n`);

  try {
    switch (action) {
      case 'show':
        results.push(await showConfig(config, format));
        break;
      case 'compare':
        results.push(await compareConfigs(env1, env2));
        break;
      case 'validate':
        results.push(await validateConfig(config));
        break;
      case 'merge':
        results.push(await mergeConfigs(env1, config));
        break;
      case 'diff':
        results.push(await diffConfigs(env1, env2));
        break;
      default:
        results.push(`未知操作: ${action}`);
    }
  } catch (error) {
    results.push(`\n### 错误\n\n操作失败: ${error}`);
  }

  return {
    content: [{ type: 'text', text: results.join('\n') }],
  };
}

// 显示配置
async function showConfig(
  configPath?: string,
  format?: string
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置内容\n');

  try {
    let config: unknown;

    if (configPath && !configPath.includes('.')) {
      // 配置节点路径，如 "project.name"
      const fullConfig = await getCentralConfig();
      config = getNestedValue(fullConfig, configPath);
      lines.push(`### 节点: ${configPath}\n`);
    } else {
      // 配置文件路径
      config = configPath
        ? await readYamlConfig(configPath)
        : await getCentralConfig();
      lines.push(`### 文件: ${configPath || 'central-config.yaml'}\n`);
    }

    if (format === 'json') {
      lines.push(`\`\`\`json\n${JSON.stringify(config, null, 2)}\n\`\`\``);
    } else if (format === 'table' && typeof config === 'object' && config !== null) {
      lines.push(objectToTable(config as Record<string, unknown>));
    } else {
      lines.push(formatYamlBlock(config));
    }
  } catch (error) {
    lines.push(`读取配置失败: ${error}`);
  }

  return lines.join('\n');
}

// 比较配置
async function compareConfigs(
  env1?: string,
  env2?: string
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置比较\n');

  if (!env1 || !env2) {
    lines.push('请指定两个环境进行比较。');
    lines.push('\n可用环境: development, staging, production');
    return lines.join('\n');
  }

  lines.push(`比较 **${env1}** 和 **${env2}**\n`);

  try {
    const config = (await getCentralConfig()) as {
      environments?: Record<string, Record<string, unknown>>;
    };

    const config1 = config?.environments?.[env1] || {};
    const config2 = config?.environments?.[env2] || {};

    // 获取所有键
    const allKeys = new Set([
      ...Object.keys(config1),
      ...Object.keys(config2),
    ]);

    const rows: string[][] = [];
    for (const key of allKeys) {
      const val1 = config1[key] ?? '(未定义)';
      const val2 = config2[key] ?? '(未定义)';
      const status =
        JSON.stringify(val1) === JSON.stringify(val2)
          ? '相同'
          : '**不同**';
      rows.push([key, String(val1), String(val2), status]);
    }

    lines.push(formatTable([`配置项`, env1, env2, '状态'], rows));
  } catch (error) {
    lines.push(`比较失败: ${error}`);
  }

  return lines.join('\n');
}

// 验证配置
async function validateConfig(configPath?: string): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置验证\n');

  try {
    const validateArgs = configPath ? [configPath] : [];
    const result = await executeScript('validate-config.sh', validateArgs);

    if (result.exitCode === 0) {
      lines.push('### ✅ 验证通过\n');
      if (result.stdout) {
        lines.push(`\`\`\`\n${result.stdout}\n\`\`\``);
      }
    } else {
      lines.push('### ❌ 验证失败\n');
      lines.push(`\`\`\`\n${result.stderr || result.stdout}\n\`\`\``);
    }
  } catch (error) {
    lines.push(`验证失败: ${error}`);
  }

  return lines.join('\n');
}

// 合并配置
async function mergeConfigs(
  environment?: string,
  outputPath?: string
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置合并\n');

  if (!environment) {
    lines.push('请指定要合并的环境。');
    lines.push('\n可用环境: development, staging, production');
    return lines.join('\n');
  }

  try {
    const mergeArgs = ['-e', environment];
    if (outputPath) {
      mergeArgs.push('-O', outputPath);
    } else {
      mergeArgs.push('--dry-run');
    }

    const result = await executeScript('config-merger.sh', mergeArgs);

    if (result.exitCode === 0) {
      lines.push(`### 环境: ${environment}\n`);
      if (outputPath) {
        lines.push(`✅ 配置已合并到: ${outputPath}`);
      } else {
        lines.push('### 合并预览\n');
        lines.push(`\`\`\`yaml\n${result.stdout}\n\`\`\``);
      }
    } else {
      lines.push('### ❌ 合并失败\n');
      lines.push(`\`\`\`\n${result.stderr}\n\`\`\``);
    }
  } catch (error) {
    lines.push(`合并失败: ${error}`);
  }

  return lines.join('\n');
}

// 配置差异
async function diffConfigs(
  file1?: string,
  file2?: string
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置差异\n');

  if (!file1 || !file2) {
    lines.push('请指定两个配置文件进行差异比较。');
    return lines.join('\n');
  }

  try {
    const result = await executeScript('config-merger.sh', [
      '--diff',
      file1,
      file2,
    ]);

    if (result.stdout) {
      lines.push(`\`\`\`diff\n${result.stdout}\n\`\`\``);
    } else {
      lines.push('两个配置文件相同，无差异。');
    }
  } catch (error) {
    lines.push(`差异比较失败: ${error}`);
  }

  return lines.join('\n');
}

// 工具函数：获取嵌套值
function getNestedValue(obj: unknown, path: string): unknown {
  const keys = path.split('.');
  let current = obj;

  for (const key of keys) {
    if (current && typeof current === 'object' && key in current) {
      current = (current as Record<string, unknown>)[key];
    } else {
      return undefined;
    }
  }

  return current;
}

// 工具函数：对象转表格
function objectToTable(obj: Record<string, unknown>, prefix = ''): string {
  const rows: string[][] = [];

  for (const [key, value] of Object.entries(obj)) {
    const fullKey = prefix ? `${prefix}.${key}` : key;

    if (typeof value === 'object' && value !== null && !Array.isArray(value)) {
      // 递归处理嵌套对象
      const nestedTable = objectToTable(
        value as Record<string, unknown>,
        fullKey
      );
      rows.push(...parseTableRows(nestedTable));
    } else {
      rows.push([fullKey, String(value)]);
    }
  }

  return formatTable(['配置项', '值'], rows);
}

// 解析表格行
function parseTableRows(tableStr: string): string[][] {
  const lines = tableStr.split('\n').filter((l) => l.startsWith('|'));
  return lines.slice(2).map((line) =>
    line
      .split('|')
      .slice(1, -1)
      .map((cell) => cell.trim())
  );
}
