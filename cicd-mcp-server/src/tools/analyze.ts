/**
 * Analyze Tool
 *
 * 分析 CI/CD 相关数据的工具
 * 支持:
 * - 日志分析
 * - 配置分析
 * - 部署失败分析
 * - 性能分析
 */

import { Tool } from '@modelcontextprotocol/sdk/types.js';
import {
  executeAicd,
  executeScript,
  getTimestamp,
  truncateText,
} from '../utils/helpers.js';

// 工具定义
export const analyzeTool: Tool = {
  name: 'cicd_analyze',
  description: `分析 CI/CD 日志、配置和部署情况。使用 AI 进行智能分析，提供问题根因和解决建议。

使用场景:
- "分析最近的部署失败"
- "检查日志中的错误"
- "审计配置文件安全性"
- "分析系统性能问题"`,
  inputSchema: {
    type: 'object',
    properties: {
      type: {
        type: 'string',
        enum: ['logs', 'config', 'deploy', 'performance', 'security'],
        description:
          '分析类型: logs(日志), config(配置), deploy(部署), performance(性能), security(安全)',
        default: 'logs',
      },
      target: {
        type: 'string',
        description: '分析目标 (日志文件路径、配置文件路径等)',
      },
      query: {
        type: 'string',
        description: '查询关键词或问题描述',
      },
      timeRange: {
        type: 'string',
        enum: ['1h', '6h', '24h', '7d', '30d'],
        description: '时间范围',
        default: '24h',
      },
      detailed: {
        type: 'boolean',
        description: '是否输出详细分析',
        default: false,
      },
    },
    required: ['type'],
  },
};

type AnalyzeType = 'logs' | 'config' | 'deploy' | 'performance' | 'security';

interface AnalyzeArgs {
  type: AnalyzeType;
  target?: string;
  query?: string;
  timeRange?: string;
  detailed?: boolean;
}

// 处理分析请求
export async function handleAnalyze(args: unknown): Promise<{
  content: Array<{ type: string; text: string }>;
}> {
  const {
    type,
    target,
    query,
    timeRange = '24h',
    detailed = false,
  } = args as AnalyzeArgs;

  const results: string[] = [];
  results.push(`# 分析报告\n`);
  results.push(`> 时间: ${getTimestamp()}`);
  results.push(`> 类型: ${type}`);
  if (target) {
    results.push(`> 目标: ${target}`);
  }
  if (query) {
    results.push(`> 查询: ${query}`);
  }
  results.push(`> 时间范围: ${timeRange}\n`);

  try {
    switch (type) {
      case 'logs':
        results.push(await analyzeLogs(target, query, detailed));
        break;
      case 'config':
        results.push(await analyzeConfig(target, detailed));
        break;
      case 'deploy':
        results.push(await analyzeDeployment(timeRange, detailed));
        break;
      case 'performance':
        results.push(await analyzePerformance(detailed));
        break;
      case 'security':
        results.push(await analyzeSecurity(target, detailed));
        break;
      default:
        results.push(`未知的分析类型: ${type}`);
    }
  } catch (error) {
    results.push(`\n### 错误\n\n分析过程中发生错误: ${error}`);
  }

  return {
    content: [{ type: 'text', text: results.join('\n') }],
  };
}

// 分析日志
async function analyzeLogs(
  target?: string,
  query?: string,
  detailed?: boolean
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 日志分析\n');

  try {
    // 使用 AI 日志分析
    const analyzeArgs = ['analyze-logs'];
    if (target) {
      analyzeArgs.push(target);
    }

    const result = await executeAicd('ai', analyzeArgs, {
      timeout: 60000,
    });

    if (result.exitCode === 0 && result.stdout) {
      lines.push(result.stdout);
    } else {
      // 降级到基本日志分析
      lines.push('### 基本分析\n');

      // 使用日志管理器查询
      const logArgs = ['query'];
      if (query) {
        logArgs.push(query);
      }
      logArgs.push('7'); // 最近 7 天

      const logResult = await executeScript('log-manager.sh', logArgs);

      if (logResult.stdout) {
        lines.push('#### 匹配的日志条目\n');
        lines.push(`\`\`\`\n${truncateText(logResult.stdout, 2000)}\n\`\`\``);
      } else {
        lines.push('未找到匹配的日志条目');
      }
    }

    if (detailed) {
      lines.push('\n### 分析建议\n');
      lines.push('- 检查错误日志的上下文');
      lines.push('- 关注重复出现的错误模式');
      lines.push('- 查看错误发生的时间规律');
    }
  } catch (error) {
    lines.push(`日志分析失败: ${error}`);
  }

  return lines.join('\n');
}

// 分析配置
async function analyzeConfig(
  target?: string,
  detailed?: boolean
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 配置分析\n');

  try {
    // 使用 AI 配置审计
    const auditArgs = ['audit-config'];
    if (target) {
      auditArgs.push(target);
    }

    const result = await executeAicd('ai', auditArgs, {
      timeout: 60000,
    });

    if (result.exitCode === 0 && result.stdout) {
      lines.push(result.stdout);
    } else {
      // 降级到基本配置验证
      lines.push('### 配置验证\n');

      const validateResult = await executeAicd('validate');

      if (validateResult.exitCode === 0) {
        lines.push('✅ 配置验证通过\n');
      } else {
        lines.push('❌ 配置验证失败\n');
        lines.push(`\`\`\`\n${validateResult.stderr}\n\`\`\``);
      }
    }

    if (detailed) {
      lines.push('\n### 配置建议\n');
      lines.push('- 定期审计敏感配置');
      lines.push('- 使用环境变量管理密钥');
      lines.push('- 启用配置版本控制');
    }
  } catch (error) {
    lines.push(`配置分析失败: ${error}`);
  }

  return lines.join('\n');
}

// 分析部署
async function analyzeDeployment(
  timeRange: string,
  detailed?: boolean
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 部署分析\n');

  try {
    // 检测最近的部署问题
    const detectArgs = ['detect-errors'];

    const result = await executeAicd('ai', detectArgs, {
      timeout: 60000,
    });

    if (result.exitCode === 0 && result.stdout) {
      lines.push('### 错误检测结果\n');
      lines.push(result.stdout);
    }

    // 使用诊断命令
    const doctorResult = await executeAicd('doctor');
    lines.push('\n### 系统诊断\n');
    lines.push(`\`\`\`\n${truncateText(doctorResult.stdout, 1500)}\n\`\`\``);

    if (detailed) {
      lines.push('\n### 部署建议\n');
      lines.push('- 实施蓝绿部署策略');
      lines.push('- 设置自动回滚阈值');
      lines.push('- 添加部署后健康检查');
      lines.push('- 使用金丝雀发布降低风险');
    }
  } catch (error) {
    lines.push(`部署分析失败: ${error}`);
  }

  return lines.join('\n');
}

// 分析性能
async function analyzePerformance(detailed?: boolean): Promise<string> {
  const lines: string[] = [];
  lines.push('## 性能分析\n');

  try {
    // 运行性能基准测试
    const benchmarkResult = await executeAicd('benchmark', [], {
      timeout: 120000,
    });

    if (benchmarkResult.exitCode === 0 && benchmarkResult.stdout) {
      lines.push('### 基准测试结果\n');
      lines.push(`\`\`\`\n${truncateText(benchmarkResult.stdout, 2000)}\n\`\`\``);
    }

    // 资源监控
    const monitorResult = await executeAicd('monitor', []);

    if (monitorResult.exitCode === 0 && monitorResult.stdout) {
      lines.push('\n### 资源使用\n');
      lines.push(`\`\`\`\n${truncateText(monitorResult.stdout, 1000)}\n\`\`\``);
    }

    if (detailed) {
      lines.push('\n### 性能建议\n');
      lines.push('- 优化构建缓存策略');
      lines.push('- 并行化测试执行');
      lines.push('- 使用增量构建');
      lines.push('- 优化 Docker 镜像大小');
    }
  } catch (error) {
    lines.push(`性能分析失败: ${error}`);
  }

  return lines.join('\n');
}

// 分析安全
async function analyzeSecurity(
  target?: string,
  detailed?: boolean
): Promise<string> {
  const lines: string[] = [];
  lines.push('## 安全分析\n');

  try {
    // 使用 AI 安全检查
    const securityArgs = ['check-security'];
    if (target) {
      securityArgs.push(target);
    }

    const result = await executeAicd('ai', securityArgs, {
      timeout: 60000,
    });

    if (result.exitCode === 0 && result.stdout) {
      lines.push(result.stdout);
    } else {
      // 降级到基本安全检查
      lines.push('### 基本安全检查\n');

      // 运行代码检查
      const lintResult = await executeScript('lint.sh', []);
      lines.push('#### 代码质量\n');
      if (lintResult.exitCode === 0) {
        lines.push('✅ ShellCheck 检查通过');
      } else {
        lines.push('⚠️ ShellCheck 发现问题\n');
        lines.push(`\`\`\`\n${truncateText(lintResult.stdout, 1000)}\n\`\`\``);
      }
    }

    if (detailed) {
      lines.push('\n### 安全建议\n');
      lines.push('- 定期更新依赖');
      lines.push('- 扫描敏感信息泄露');
      lines.push('- 使用安全的密钥管理');
      lines.push('- 启用代码签名');
      lines.push('- 实施最小权限原则');
    }
  } catch (error) {
    lines.push(`安全分析失败: ${error}`);
  }

  return lines.join('\n');
}
