/**
 * Status Tool
 *
 * 查看 CI/CD 状态的工具
 * 支持:
 * - 项目状态
 * - 流水线状态
 * - 部署状态
 * - 健康检查
 */

import { Tool } from '@modelcontextprotocol/sdk/types.js';
import {
  executeAicd,
  executeScript,
  getCentralConfig,
  formatAsMarkdown,
  formatTable,
  getTimestamp,
} from '../utils/helpers.js';

// 工具定义
export const statusTool: Tool = {
  name: 'cicd_status',
  description: `查看 CI/CD 系统状态。可以查看项目配置、流水线状态、部署状态和系统健康状况。

使用场景:
- "查看当前项目状态"
- "检查部署是否成功"
- "系统健康状况如何"
- "显示 CI/CD 配置"`,
  inputSchema: {
    type: 'object',
    properties: {
      type: {
        type: 'string',
        enum: ['project', 'pipeline', 'deploy', 'health', 'all'],
        description: '状态类型: project(项目), pipeline(流水线), deploy(部署), health(健康), all(全部)',
        default: 'all',
      },
      environment: {
        type: 'string',
        enum: ['development', 'staging', 'production'],
        description: '环境名称',
      },
      verbose: {
        type: 'boolean',
        description: '是否显示详细信息',
        default: false,
      },
    },
    required: [],
  },
};

// 状态类型
type StatusType = 'project' | 'pipeline' | 'deploy' | 'health' | 'all';

interface StatusArgs {
  type?: StatusType;
  environment?: string;
  verbose?: boolean;
}

// 处理状态查询
export async function handleStatus(args: unknown): Promise<{
  content: Array<{ type: string; text: string }>;
}> {
  const { type = 'all', environment, verbose = false } = args as StatusArgs;

  const results: string[] = [];
  results.push(`# CI/CD 状态报告\n`);
  results.push(`> 生成时间: ${getTimestamp()}\n`);

  if (environment) {
    results.push(`> 环境: ${environment}\n`);
  }

  try {
    switch (type) {
      case 'project':
        results.push(await getProjectStatus(verbose));
        break;
      case 'pipeline':
        results.push(await getPipelineStatus(verbose));
        break;
      case 'deploy':
        results.push(await getDeployStatus(environment, verbose));
        break;
      case 'health':
        results.push(await getHealthStatus(verbose));
        break;
      case 'all':
      default:
        results.push(await getProjectStatus(verbose));
        results.push(await getPipelineStatus(verbose));
        results.push(await getDeployStatus(environment, verbose));
        results.push(await getHealthStatus(verbose));
        break;
    }
  } catch (error) {
    results.push(`\n### 错误\n\n获取状态时发生错误: ${error}`);
  }

  return {
    content: [
      {
        type: 'text',
        text: results.join('\n'),
      },
    ],
  };
}

// 获取项目状态
async function getProjectStatus(verbose: boolean): Promise<string> {
  const lines: string[] = [];
  lines.push('## 项目状态\n');

  try {
    // 读取中央配置
    const config = (await getCentralConfig()) as {
      project?: { name?: string; version?: string; description?: string };
    };

    if (config?.project) {
      lines.push(
        formatTable(
          ['属性', '值'],
          [
            ['项目名称', config.project.name || 'N/A'],
            ['版本', config.project.version || 'N/A'],
            ['描述', config.project.description || 'N/A'],
          ]
        )
      );
    } else {
      lines.push('未找到项目配置');
    }

    if (verbose) {
      // 运行验证
      const validateResult = await executeAicd('validate');
      lines.push('\n### 配置验证\n');
      lines.push(
        validateResult.exitCode === 0
          ? '✅ 配置验证通过'
          : `❌ 配置验证失败\n\`\`\`\n${validateResult.stderr}\n\`\`\``
      );
    }
  } catch (error) {
    lines.push(`获取项目状态失败: ${error}`);
  }

  return lines.join('\n');
}

// 获取流水线状态
async function getPipelineStatus(verbose: boolean): Promise<string> {
  const lines: string[] = [];
  lines.push('\n## 流水线状态\n');

  try {
    // 检查脚本可用性
    const scripts = [
      { name: 'aicd.sh', desc: 'CLI 工具' },
      { name: 'ai-supervisor.sh', desc: 'AI 监督' },
      { name: 'config-wizard.sh', desc: '配置向导' },
      { name: 'lint.sh', desc: '代码检查' },
    ];

    const scriptStatus: string[][] = [];
    for (const script of scripts) {
      try {
        const result = await executeScript(script.name, ['--help'], { timeout: 5000 });
        scriptStatus.push([script.name, script.desc, result.exitCode === 0 ? '✅ 可用' : '⚠️ 异常']);
      } catch {
        scriptStatus.push([script.name, script.desc, '❌ 不可用']);
      }
    }

    lines.push(formatTable(['脚本', '功能', '状态'], scriptStatus));

    if (verbose) {
      // 运行诊断
      const doctorResult = await executeAicd('doctor');
      lines.push('\n### 诊断结果\n');
      lines.push(`\`\`\`\n${doctorResult.stdout || doctorResult.stderr}\n\`\`\``);
    }
  } catch (error) {
    lines.push(`获取流水线状态失败: ${error}`);
  }

  return lines.join('\n');
}

// 获取部署状态
async function getDeployStatus(
  environment?: string,
  verbose?: boolean
): Promise<string> {
  const lines: string[] = [];
  lines.push('\n## 部署状态\n');

  try {
    // 读取配置获取部署信息
    const config = (await getCentralConfig()) as {
      deploy?: {
        rollback_enabled?: boolean;
        commands?: string[];
      };
      rollback?: {
        strategies?: string[];
        auto_rollback_on_failure?: boolean;
      };
      environments?: Record<
        string,
        { debug?: boolean; log_level?: string }
      >;
    };

    // 环境状态
    if (config?.environments) {
      const envs = Object.entries(config.environments);
      const envStatus: string[][] = envs.map(([name, cfg]) => [
        name,
        cfg.log_level || 'N/A',
        cfg.debug ? '🔧 Debug' : '📦 Production',
        environment === name ? '⬅️ 当前' : '',
      ]);

      lines.push(formatTable(['环境', '日志级别', '模式', ''], envStatus));
    }

    // 回滚配置
    if (config?.rollback) {
      lines.push('\n### 回滚配置\n');
      lines.push(`- 策略: ${config.rollback.strategies?.join(', ') || 'N/A'}`);
      lines.push(
        `- 自动回滚: ${config.rollback.auto_rollback_on_failure ? '✅ 启用' : '❌ 禁用'}`
      );
    }

    if (verbose && config?.deploy?.commands) {
      lines.push('\n### 部署命令\n');
      config.deploy.commands.forEach((cmd, i) => {
        lines.push(`${i + 1}. \`${cmd}\``);
      });
    }
  } catch (error) {
    lines.push(`获取部署状态失败: ${error}`);
  }

  return lines.join('\n');
}

// 获取健康状态
async function getHealthStatus(verbose: boolean): Promise<string> {
  const lines: string[] = [];
  lines.push('\n## 系统健康\n');

  try {
    // 使用 AI 健康检查
    const healthResult = await executeAicd('ai', ['health-check']);

    if (healthResult.exitCode === 0) {
      lines.push(healthResult.stdout);
    } else {
      // 降级到基本健康检查
      lines.push('### 基本健康检查\n');

      const checks: string[][] = [];

      // 检查配置文件
      try {
        await getCentralConfig();
        checks.push(['配置文件', '✅ 正常']);
      } catch {
        checks.push(['配置文件', '❌ 异常']);
      }

      // 检查脚本目录
      const doctorResult = await executeAicd('doctor');
      checks.push([
        'CI/CD 工具',
        doctorResult.exitCode === 0 ? '✅ 正常' : '⚠️ 部分异常',
      ]);

      lines.push(formatTable(['检查项', '状态'], checks));

      if (verbose && healthResult.stderr) {
        lines.push(`\n### 详细信息\n\`\`\`\n${healthResult.stderr}\n\`\`\``);
      }
    }
  } catch (error) {
    lines.push(`获取健康状态失败: ${error}`);
  }

  return lines.join('\n');
}
