/**
 * Deploy Tool
 *
 * 触发部署的工具
 * 支持:
 * - 指定环境部署
 * - 指定版本部署
 * - 部署预检查
 * - 部署状态跟踪
 */

import { Tool } from '@modelcontextprotocol/sdk/types.js';
import {
  executeAicd,
  getCentralConfig,
  formatAsMarkdown,
  getTimestamp,
} from '../utils/helpers.js';

// 工具定义
export const deployTool: Tool = {
  name: 'cicd_deploy',
  description: `触发 CI/CD 部署。可以将项目部署到指定环境，支持版本控制和预检查。

使用场景:
- "帮我部署到 staging 环境"
- "部署 v1.2.0 到 production"
- "执行部署预检查"
- "查看部署是否可行"`,
  inputSchema: {
    type: 'object',
    properties: {
      environment: {
        type: 'string',
        enum: ['development', 'staging', 'production'],
        description: '目标部署环境',
        default: 'staging',
      },
      version: {
        type: 'string',
        description: '要部署的版本号 (如: v1.2.0)',
      },
      dryRun: {
        type: 'boolean',
        description: '是否只执行预检查，不实际部署',
        default: false,
      },
      force: {
        type: 'boolean',
        description: '是否跳过确认直接部署 (生产环境需要特别确认)',
        default: false,
      },
    },
    required: ['environment'],
  },
};

interface DeployArgs {
  environment: string;
  version?: string;
  dryRun?: boolean;
  force?: boolean;
}

// 处理部署请求
export async function handleDeploy(args: unknown): Promise<{
  content: Array<{ type: string; text: string }>;
}> {
  const {
    environment,
    version,
    dryRun = false,
    force = false,
  } = args as DeployArgs;

  const results: string[] = [];
  results.push(`# 部署操作\n`);
  results.push(`> 时间: ${getTimestamp()}`);
  results.push(`> 环境: ${environment}`);
  if (version) {
    results.push(`> 版本: ${version}`);
  }
  results.push(`> 模式: ${dryRun ? '预检查' : '实际部署'}\n`);

  try {
    // 生产环境警告
    if (environment === 'production' && !dryRun) {
      if (!force) {
        results.push('## ⚠️ 生产环境部署警告\n');
        results.push('您正在尝试部署到生产环境。这是一个高风险操作。\n');
        results.push('请确认以下事项:');
        results.push('- 已完成所有测试');
        results.push('- 已在 staging 环境验证');
        results.push('- 已准备好回滚计划\n');
        results.push(
          '如果确认要继续，请使用 `force: true` 参数重新调用。'
        );
        return {
          content: [{ type: 'text', text: results.join('\n') }],
        };
      }
      results.push('⚠️ **强制模式**: 跳过确认，直接部署到生产环境\n');
    }

    // 预检查
    results.push('## 部署预检查\n');
    const preCheckResult = await runPreCheck(environment);
    results.push(preCheckResult.message);

    if (!preCheckResult.passed) {
      results.push('\n### ❌ 预检查失败\n');
      results.push('部署已取消。请解决以上问题后重试。');
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    results.push('\n### ✅ 预检查通过\n');

    if (dryRun) {
      results.push('---\n');
      results.push('**预检查模式**: 实际部署未执行。');
      results.push('所有检查已通过，可以安全部署。');
      return {
        content: [{ type: 'text', text: results.join('\n') }],
      };
    }

    // 执行部署
    results.push('## 执行部署\n');

    const deployArgs = ['--env', environment];
    if (version) {
      deployArgs.push('--version', version);
    }

    const deployResult = await executeAicd('deploy', deployArgs, {
      timeout: 300000, // 5 分钟超时
    });

    if (deployResult.exitCode === 0) {
      results.push('### ✅ 部署成功\n');
      results.push(`\`\`\`\n${deployResult.stdout}\n\`\`\``);

      results.push('\n### 后续步骤\n');
      results.push('- 验证部署结果');
      results.push('- 运行冒烟测试');
      results.push('- 监控应用日志');
    } else {
      results.push('### ❌ 部署失败\n');
      results.push(
        `\`\`\`\n${deployResult.stderr || deployResult.stdout}\n\`\`\``
      );

      // 检查是否需要回滚
      const config = (await getCentralConfig()) as {
        rollback?: { auto_rollback_on_failure?: boolean };
      };

      if (config?.rollback?.auto_rollback_on_failure) {
        results.push('\n### 自动回滚\n');
        results.push('检测到自动回滚已启用，系统正在尝试回滚...');
      } else {
        results.push('\n### 建议操作\n');
        results.push('- 使用 `cicd_rollback` 工具手动回滚');
        results.push('- 使用 `cicd_analyze` 工具分析失败原因');
      }
    }
  } catch (error) {
    results.push(`\n### 错误\n\n部署过程中发生错误: ${error}`);
  }

  return {
    content: [{ type: 'text', text: results.join('\n') }],
  };
}

// 运行预检查
async function runPreCheck(
  environment: string
): Promise<{ passed: boolean; message: string }> {
  const checks: string[] = [];
  let allPassed = true;

  // 1. 验证配置
  try {
    const validateResult = await executeAicd('validate');
    if (validateResult.exitCode === 0) {
      checks.push('- ✅ 配置验证通过');
    } else {
      checks.push(`- ❌ 配置验证失败: ${validateResult.stderr}`);
      allPassed = false;
    }
  } catch (error) {
    checks.push(`- ❌ 配置验证异常: ${error}`);
    allPassed = false;
  }

  // 2. 检查环境配置
  try {
    const config = (await getCentralConfig()) as {
      environments?: Record<string, unknown>;
    };
    if (config?.environments?.[environment]) {
      checks.push(`- ✅ 环境配置存在: ${environment}`);
    } else {
      checks.push(`- ❌ 环境配置不存在: ${environment}`);
      allPassed = false;
    }
  } catch (error) {
    checks.push(`- ❌ 读取环境配置失败: ${error}`);
    allPassed = false;
  }

  // 3. 运行诊断
  try {
    const doctorResult = await executeAicd('doctor');
    if (doctorResult.exitCode === 0) {
      checks.push('- ✅ 系统诊断通过');
    } else {
      checks.push('- ⚠️ 系统诊断发现问题 (可能不影响部署)');
    }
  } catch {
    checks.push('- ⚠️ 系统诊断跳过');
  }

  // 4. 生产环境额外检查
  if (environment === 'production') {
    checks.push('- ℹ️ 生产环境部署需要额外确认');
  }

  return {
    passed: allPassed,
    message: checks.join('\n'),
  };
}
