/**
 * MCP Resources
 *
 * 提供 CI/CD 相关资源的读取
 * 支持:
 * - 流水线配置
 * - 环境配置
 * - 部署历史
 * - 日志文件
 */

import { readFile, readdir, stat } from 'fs/promises';
import * as path from 'path';
import YAML from 'yaml';
import {
  getConfigDir,
  getProjectRoot,
  getCentralConfig,
  formatYamlBlock,
} from '../utils/helpers.js';

// 资源 URI 前缀
const URI_PREFIX = 'cicd://';

// 资源类型
interface Resource {
  uri: string;
  name: string;
  description: string;
  mimeType: string;
}

// 列出可用资源
export async function handleListResources(): Promise<{
  resources: Resource[];
}> {
  const resources: Resource[] = [];

  // 配置资源
  resources.push({
    uri: `${URI_PREFIX}config/central`,
    name: '中央配置',
    description: 'CI/CD 中央配置文件 (central-config.yaml)',
    mimeType: 'application/x-yaml',
  });

  resources.push({
    uri: `${URI_PREFIX}config/ai`,
    name: 'AI 配置',
    description: 'AI 监督功能配置 (ai-config.yaml)',
    mimeType: 'application/x-yaml',
  });

  // 环境配置
  const environments = ['development', 'staging', 'production'];
  for (const env of environments) {
    resources.push({
      uri: `${URI_PREFIX}config/environment/${env}`,
      name: `${env} 环境配置`,
      description: `${env} 环境的配置覆盖`,
      mimeType: 'application/x-yaml',
    });
  }

  // 流水线配置
  resources.push({
    uri: `${URI_PREFIX}pipeline/build`,
    name: '构建流水线',
    description: '项目构建配置和命令',
    mimeType: 'application/json',
  });

  resources.push({
    uri: `${URI_PREFIX}pipeline/test`,
    name: '测试流水线',
    description: '测试配置和覆盖率阈值',
    mimeType: 'application/json',
  });

  resources.push({
    uri: `${URI_PREFIX}pipeline/deploy`,
    name: '部署流水线',
    description: '部署配置和回滚策略',
    mimeType: 'application/json',
  });

  // 模板资源
  resources.push({
    uri: `${URI_PREFIX}templates/github-actions`,
    name: 'GitHub Actions 模板',
    description: '可用的 GitHub Actions 工作流模板',
    mimeType: 'application/json',
  });

  resources.push({
    uri: `${URI_PREFIX}templates/docker`,
    name: 'Docker 模板',
    description: '可用的 Docker 配置模板',
    mimeType: 'application/json',
  });

  resources.push({
    uri: `${URI_PREFIX}templates/kubernetes`,
    name: 'Kubernetes 模板',
    description: '可用的 Kubernetes 部署模板',
    mimeType: 'application/json',
  });

  // 脚本资源
  resources.push({
    uri: `${URI_PREFIX}scripts/list`,
    name: '可用脚本列表',
    description: 'CI/CD 可用的脚本工具列表',
    mimeType: 'application/json',
  });

  return { resources };
}

// 读取资源内容
export async function handleReadResource(uri: string): Promise<{
  contents: Array<{
    uri: string;
    mimeType: string;
    text: string;
  }>;
}> {
  if (!uri.startsWith(URI_PREFIX)) {
    throw new Error(`Invalid resource URI: ${uri}`);
  }

  const resourcePath = uri.slice(URI_PREFIX.length);
  const parts = resourcePath.split('/');

  let content: string;
  let mimeType: string;

  try {
    switch (parts[0]) {
      case 'config':
        ({ content, mimeType } = await readConfigResource(parts.slice(1)));
        break;
      case 'pipeline':
        ({ content, mimeType } = await readPipelineResource(parts[1]));
        break;
      case 'templates':
        ({ content, mimeType } = await readTemplatesResource(parts[1]));
        break;
      case 'scripts':
        ({ content, mimeType } = await readScriptsResource(parts[1]));
        break;
      default:
        throw new Error(`Unknown resource type: ${parts[0]}`);
    }
  } catch (error) {
    content = `Error reading resource: ${error}`;
    mimeType = 'text/plain';
  }

  return {
    contents: [
      {
        uri,
        mimeType,
        text: content,
      },
    ],
  };
}

// 读取配置资源
async function readConfigResource(
  parts: string[]
): Promise<{ content: string; mimeType: string }> {
  const configDir = getConfigDir();

  switch (parts[0]) {
    case 'central': {
      const filePath = path.join(configDir, 'central-config.yaml');
      const content = await readFile(filePath, 'utf-8');
      return { content, mimeType: 'application/x-yaml' };
    }

    case 'ai': {
      const filePath = path.join(configDir, 'ai-config.yaml');
      const content = await readFile(filePath, 'utf-8');
      return { content, mimeType: 'application/x-yaml' };
    }

    case 'environment': {
      const env = parts[1];
      if (!env) {
        throw new Error('Environment name required');
      }

      // 尝试读取环境配置文件
      const envFile = path.join(configDir, 'environment', `${env}.yaml`);
      try {
        const content = await readFile(envFile, 'utf-8');
        return { content, mimeType: 'application/x-yaml' };
      } catch {
        // 如果文件不存在，从中央配置提取
        const centralConfig = (await getCentralConfig()) as {
          environments?: Record<string, unknown>;
        };
        const envConfig = centralConfig?.environments?.[env] || {};
        return {
          content: YAML.stringify(envConfig),
          mimeType: 'application/x-yaml',
        };
      }
    }

    default:
      throw new Error(`Unknown config resource: ${parts[0]}`);
  }
}

// 读取流水线资源
async function readPipelineResource(
  pipeline: string
): Promise<{ content: string; mimeType: string }> {
  const centralConfig = (await getCentralConfig()) as Record<string, unknown>;

  switch (pipeline) {
    case 'build': {
      const buildConfig = centralConfig.build || {};
      return {
        content: JSON.stringify(buildConfig, null, 2),
        mimeType: 'application/json',
      };
    }

    case 'test': {
      const testConfig = centralConfig.test || {};
      return {
        content: JSON.stringify(testConfig, null, 2),
        mimeType: 'application/json',
      };
    }

    case 'deploy': {
      const deployConfig = {
        deploy: centralConfig.deploy || {},
        rollback: centralConfig.rollback || {},
      };
      return {
        content: JSON.stringify(deployConfig, null, 2),
        mimeType: 'application/json',
      };
    }

    default:
      throw new Error(`Unknown pipeline: ${pipeline}`);
  }
}

// 读取模板资源
async function readTemplatesResource(
  templateType: string
): Promise<{ content: string; mimeType: string }> {
  const templatesDir = path.join(getProjectRoot(), 'templates', templateType);

  try {
    const files = await readdir(templatesDir);
    const templates: Array<{
      name: string;
      path: string;
      description: string;
    }> = [];

    for (const file of files) {
      const filePath = path.join(templatesDir, file);
      const fileStat = await stat(filePath);

      if (fileStat.isFile()) {
        templates.push({
          name: file,
          path: `templates/${templateType}/${file}`,
          description: getTemplateDescription(templateType, file),
        });
      }
    }

    return {
      content: JSON.stringify({ templates }, null, 2),
      mimeType: 'application/json',
    };
  } catch {
    return {
      content: JSON.stringify({
        error: `Template directory not found: ${templateType}`,
        templates: [],
      }),
      mimeType: 'application/json',
    };
  }
}

// 读取脚本资源
async function readScriptsResource(
  action: string
): Promise<{ content: string; mimeType: string }> {
  const scriptsDir = path.join(getProjectRoot(), 'scripts');

  if (action === 'list') {
    try {
      const files = await readdir(scriptsDir);
      const scripts: Array<{
        name: string;
        description: string;
        usage: string;
      }> = [];

      for (const file of files) {
        if (file.endsWith('.sh')) {
          scripts.push({
            name: file,
            description: getScriptDescription(file),
            usage: `./${file} --help`,
          });
        }
      }

      return {
        content: JSON.stringify({ scripts }, null, 2),
        mimeType: 'application/json',
      };
    } catch {
      return {
        content: JSON.stringify({ error: 'Scripts directory not found' }),
        mimeType: 'application/json',
      };
    }
  }

  throw new Error(`Unknown scripts action: ${action}`);
}

// 获取模板描述
function getTemplateDescription(type: string, file: string): string {
  const descriptions: Record<string, Record<string, string>> = {
    'github-actions': {
      'ci-cd.yaml': '完整的 CI/CD 流水线工作流',
      'pr-validation.yaml': 'Pull Request 验证工作流',
      'release.yaml': '版本发布工作流',
    },
    docker: {
      'Dockerfile.node': 'Node.js 多阶段构建 Dockerfile',
      'Dockerfile.python': 'Python 多阶段构建 Dockerfile',
      'docker-compose.dev.yaml': '开发环境 Docker Compose 配置',
      'docker-compose.prod.yaml': '生产环境 Docker Compose 配置',
    },
    kubernetes: {
      'deployment.yaml': 'Kubernetes Deployment 配置',
      'ingress.yaml': 'Kubernetes Ingress 配置',
      'service.yaml': 'Kubernetes Service 配置',
    },
  };

  return descriptions[type]?.[file] || `${type} 模板文件`;
}

// 获取脚本描述
function getScriptDescription(file: string): string {
  const descriptions: Record<string, string> = {
    'aicd.sh': '主命令行工具 - CI/CD 统一入口',
    'ai-supervisor.sh': 'AI 监督工具 - 智能分析和建议',
    'config-wizard.sh': '配置向导 - 交互式生成配置',
    'config-merger.sh': '配置合并 - 深度合并 YAML 配置',
    'lint.sh': '代码检查 - ShellCheck 静态分析',
    'validate-config.sh': '配置验证 - 验证配置文件格式',
    'log-manager.sh': '日志管理 - 日志查询和轮转',
    'api-docs-generator.sh': 'API 文档生成 - 提取函数文档',
    'config-version-manager.sh': '版本管理 - 配置版本控制',
    'resource-monitoring.sh': '资源监控 - 系统资源监控',
    'performance-benchmark.sh': '性能测试 - 基准测试工具',
  };

  return descriptions[file] || 'CI/CD 工具脚本';
}
