/**
 * 工具函数
 * 提供 Shell 脚本执行和配置读取功能
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import { readFile, access } from 'fs/promises';
import { constants } from 'fs';
import * as path from 'path';
import YAML from 'yaml';

const execAsync = promisify(exec);

// 项目根目录
export function getProjectRoot(): string {
  // 从环境变量或默认路径获取
  return process.env.CICD_PROJECT_ROOT || process.cwd();
}

// 脚本目录
export function getScriptsDir(): string {
  return path.join(getProjectRoot(), 'scripts');
}

// 配置目录
export function getConfigDir(): string {
  return path.join(getProjectRoot(), 'config');
}

/**
 * 执行 Shell 脚本
 */
export async function executeScript(
  scriptName: string,
  args: string[] = [],
  options: { timeout?: number; cwd?: string } = {}
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  const scriptPath = path.join(getScriptsDir(), scriptName);

  // 检查脚本是否存在
  try {
    await access(scriptPath, constants.X_OK);
  } catch {
    throw new Error(`Script not found or not executable: ${scriptPath}`);
  }

  const command = `"${scriptPath}" ${args.map((a) => `"${a}"`).join(' ')}`;

  try {
    const { stdout, stderr } = await execAsync(command, {
      cwd: options.cwd || getProjectRoot(),
      timeout: options.timeout || 60000,
      maxBuffer: 10 * 1024 * 1024, // 10MB
      env: {
        ...process.env,
        AICD_MCP_MODE: 'true',
      },
    });

    return {
      stdout: stdout.trim(),
      stderr: stderr.trim(),
      exitCode: 0,
    };
  } catch (error: unknown) {
    const execError = error as { stdout?: string; stderr?: string; code?: number };
    return {
      stdout: execError.stdout?.trim() || '',
      stderr: execError.stderr?.trim() || String(error),
      exitCode: execError.code || 1,
    };
  }
}

/**
 * 执行 aicd 命令
 */
export async function executeAicd(
  command: string,
  args: string[] = [],
  options: { timeout?: number } = {}
): Promise<{ stdout: string; stderr: string; exitCode: number }> {
  return executeScript('aicd.sh', [command, ...args], options);
}

/**
 * 读取 YAML 配置文件
 */
export async function readYamlConfig(configPath: string): Promise<unknown> {
  const fullPath = path.isAbsolute(configPath)
    ? configPath
    : path.join(getConfigDir(), configPath);

  try {
    const content = await readFile(fullPath, 'utf-8');
    return YAML.parse(content);
  } catch (error) {
    throw new Error(`Failed to read config file: ${fullPath} - ${error}`);
  }
}

/**
 * 获取中央配置
 */
export async function getCentralConfig(): Promise<unknown> {
  return readYamlConfig('central-config.yaml');
}

/**
 * 获取 AI 配置
 */
export async function getAiConfig(): Promise<unknown> {
  return readYamlConfig('ai-config.yaml');
}

/**
 * 格式化输出为 Markdown
 */
export function formatAsMarkdown(title: string, content: string): string {
  return `## ${title}\n\n${content}`;
}

/**
 * 格式化表格
 */
export function formatTable(
  headers: string[],
  rows: string[][]
): string {
  const headerRow = `| ${headers.join(' | ')} |`;
  const separatorRow = `| ${headers.map(() => '---').join(' | ')} |`;
  const dataRows = rows.map((row) => `| ${row.join(' | ')} |`).join('\n');

  return `${headerRow}\n${separatorRow}\n${dataRows}`;
}

/**
 * 格式化 JSON 为代码块
 */
export function formatJsonBlock(data: unknown): string {
  return `\`\`\`json\n${JSON.stringify(data, null, 2)}\n\`\`\``;
}

/**
 * 格式化 YAML 为代码块
 */
export function formatYamlBlock(data: unknown): string {
  return `\`\`\`yaml\n${YAML.stringify(data)}\`\`\``;
}

/**
 * 解析版本号
 */
export function parseVersion(version: string): {
  major: number;
  minor: number;
  patch: number;
} {
  const match = version.match(/^v?(\d+)\.(\d+)\.(\d+)/);
  if (!match) {
    throw new Error(`Invalid version format: ${version}`);
  }
  return {
    major: parseInt(match[1], 10),
    minor: parseInt(match[2], 10),
    patch: parseInt(match[3], 10),
  };
}

/**
 * 比较版本号
 */
export function compareVersions(v1: string, v2: string): number {
  const p1 = parseVersion(v1);
  const p2 = parseVersion(v2);

  if (p1.major !== p2.major) return p1.major - p2.major;
  if (p1.minor !== p2.minor) return p1.minor - p2.minor;
  return p1.patch - p2.patch;
}

/**
 * 获取当前时间戳
 */
export function getTimestamp(): string {
  return new Date().toISOString();
}

/**
 * 截断长文本
 */
export function truncateText(text: string, maxLength: number = 1000): string {
  if (text.length <= maxLength) return text;
  return text.slice(0, maxLength) + '\n... (truncated)';
}
