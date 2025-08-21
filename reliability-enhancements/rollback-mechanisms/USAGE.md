# 回滚机制增强方案使用指南

## 概述

本文档介绍了如何使用增强的回滚机制，包括蓝绿部署和金丝雀发布的自动回滚实现、回滚前的健康检查和验证机制，以及基于指标的自动回滚策略配置。

## 目录结构

```
reliability-enhancements/rollback-mechanisms/
├── blue-green-rollback.sh          # 蓝绿部署回滚脚本
├── canary-rollback.sh               # 金丝雀部署回滚脚本
├── enhanced-rollback.sh             # 增强版主回滚脚本
├── health-check.sh                  # 健康检查脚本
└── rollback-strategy-config.yaml    # 回滚策略配置文件
```

## 1. 蓝绿部署自动回滚

### 使用场景
当使用蓝绿部署策略时，如果新版本（绿色环境）出现问题，可以自动回滚到稳定的旧版本（蓝色环境）。

### 使用方法

```bash
# 基本用法
./blue-green-rollback.sh -a myapp -n production -e blue -k ~/.kube/config

# 指定超时时间和回滚原因
./blue-green-rollback.sh \
  --app myapp \
  --namespace production \
  --active-env green \
  --timeout 600 \
  --reason "新版本导致500错误率上升"
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| -a, --app | 应用名称 | 必需 |
| -n, --namespace | Kubernetes命名空间 | default |
| -e, --active-env | 当前活跃环境 (blue|green) | 必需 |
| -k, --kubeconfig | Kubernetes配置文件路径 | 可选 |
| -t, --timeout | 健康检查超时时间（秒） | 300 |
| -r, --reason | 回滚原因 | 可选 |

### 工作流程

1. 验证回滚目标环境的健康状态
2. 切换流量到回滚目标环境
3. 等待流量切换稳定
4. 验证流量切换结果
5. 清理原活跃环境

## 2. 金丝雀部署自动回滚

### 使用场景
当使用金丝雀部署策略时，如果金丝雀版本出现问题（如CPU使用率过高、错误率上升等），可以自动回滚到稳定版本。

### 使用方法

```bash
# 基本用法
./canary-rollback.sh -a myapp -n production -k ~/.kube/config

# 自定义指标阈值
./canary-rollback.sh \
  --app myapp \
  --namespace staging \
  --cpu-threshold 75 \
  --memory-threshold 75 \
  --error-threshold 3 \
  --latency-threshold 500
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| -a, --app | 应用名称 | 必需 |
| -n, --namespace | Kubernetes命名空间 | default |
| -k, --kubeconfig | Kubernetes配置文件路径 | 可选 |
| -t, --timeout | 健康检查超时时间（秒） | 300 |
| --cpu-threshold | CPU使用率阈值（百分比） | 80 |
| --memory-threshold | 内存使用率阈值（百分比） | 80 |
| --error-threshold | 错误率阈值（百分比） | 5 |
| --latency-threshold | 延迟阈值（毫秒） | 1000 |
| --canary-replicas | 金丝雀副本数 | 1 |
| -r, --reason | 回滚原因 | 可选 |

### 工作流程

1. 验证主环境的健康状态
2. 收集和分析金丝雀环境指标
3. 如果指标超过阈值，执行回滚
4. 清理金丝雀环境
5. 重置流量路由

## 3. 健康检查和验证机制

### 使用场景
在执行任何回滚操作之前，对当前环境进行健康检查，确保回滚操作的安全性。

### 使用方法

```bash
# 全面健康检查
./health-check.sh -a myapp -n production -k ~/.kube/config

# 基础健康检查
./health-check.sh -a myapp -n production -t basic

# JSON格式输出
./health-check.sh -a myapp -n production -o json
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| -a, --app | 应用名称 | 必需 |
| -n, --namespace | Kubernetes命名空间 | default |
| -k, --kubeconfig | Kubernetes配置文件路径 | 可选 |
| -t, --type | 检查类型 (comprehensive|basic|custom) | comprehensive |
| -c, --config | 配置文件路径 | 可选 |
| --timeout | 超时时间（秒） | 300 |
| -o, --output | 输出格式 (text|json) | text |

### 检查项目

**基础检查 (basic):**
- Deployment状态
- Pod状态
- 服务状态

**全面检查 (comprehensive):**
- Deployment状态和条件
- Pod状态和就绪状态
- 服务状态和端点
- 资源使用情况
- HPA状态

## 4. 增强版主回滚脚本

### 使用场景
统一的回滚入口，支持多种部署策略和健康检查。

### 使用方法

```bash
# 标准Kubernetes回滚
./enhanced-rollback.sh -t kubernetes -a myapp -n production

# 蓝绿部署回滚
./enhanced-rollback.sh \
  --target kubernetes \
  --app myapp \
  --strategy blue-green \
  --active-env blue \
  --kubeconfig ~/.kube/config

# 金丝雀部署回滚
./enhanced-rollback.sh \
  -a myapp \
  --strategy canary \
  --strategy-config ./rollback-strategy-config.yaml \
  -r "CPU使用率超过阈值"
```

### 参数说明

| 参数 | 说明 | 默认值 |
|------|------|--------|
| -t, --target | 部署目标 (kubernetes, docker-compose) | kubernetes |
| -a, --app | 应用名称 | 必需 |
| -n, --namespace | Kubernetes命名空间 | default |
| -v, --version | 回滚到指定版本 | previous |
| -s, --steps | 回滚步数 | 1 |
| --strategy | 回滚策略 (standard, blue-green, canary) | standard |
| --active-env | 当前活跃环境 (blue|green) | 必需（蓝绿部署时） |
| -k, --kubeconfig | Kubernetes配置文件路径 | 可选 |
| --health-check | 健康检查类型 | comprehensive |
| --strategy-config | 回滚策略配置文件路径 | 可选 |
| --notify | 是否在回滚时发送通知 | true |
| -r, --reason | 回滚原因 | 可选 |

## 5. 基于指标的自动回滚策略配置

### 配置文件说明

`rollback-strategy-config.yaml` 文件定义了自动回滚的触发条件和策略。

### 主要配置项

**通用配置:**
- 启用/禁用自动回滚
- 检查间隔和窗口
- 确认次数和冷却时间
- 通知配置

**蓝绿部署回滚策略:**
- 健康检查配置
- 流量切换验证

**金丝雀部署回滚策略:**
- 指标阈值配置（CPU、内存、错误率、延迟等）
- 滑动窗口配置

**业务指标回滚策略:**
- 订单量、用户活跃度、收入等业务指标阈值

**自定义指标回滚策略:**
- 支持Prometheus、Datadog、New Relic等监控系统的集成

## 6. 最佳实践

### 6.1 回滚策略选择

1. **标准回滚**: 适用于简单的版本回退
2. **蓝绿回滚**: 适用于需要零停机时间的场景
3. **金丝雀回滚**: 适用于需要精细控制风险的场景

### 6.2 健康检查配置

1. 在生产环境中启用全面健康检查
2. 根据应用特点自定义检查项
3. 设置合理的超时时间

### 6.3 指标阈值设置

1. 根据历史数据设置合理的阈值
2. 避免过于敏感或过于宽松的设置
3. 定期调整阈值以适应业务变化

### 6.4 通知机制

1. 配置多种通知渠道确保信息传达
2. 包含关键信息：应用名称、回滚原因、时间等
3. 区分不同环境的通知策略

### 6.5 测试和演练

1. 定期测试回滚流程
2. 模拟各种故障场景
3. 记录和分析回滚操作日志

## 7. 集成示例

### 7.1 GitHub Actions集成

```yaml
# 在部署流水线中集成自动回滚
- name: Monitor deployment
  run: |
    # 监控新部署的健康状态
    for i in {1..10}; do
      if ! ./health-check.sh -a myapp -n production; then
        echo "Health check failed, triggering rollback"
        ./enhanced-rollback.sh -a myapp -n production --strategy blue-green --active-env blue
        exit 1
      fi
      sleep 30
    done
```

### 7.2 Kubernetes CronJob集成

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rollback-monitor
spec:
  schedule: "*/5 * * * *"  # 每5分钟执行一次
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: rollback-monitor
            image: your-monitoring-image
            command:
            - /bin/sh
            - -c
            - |
              # 检查应用指标
              if ./health-check.sh -a myapp -n production --type comprehensive; then
                echo "Application is healthy"
              else
                echo "Application is unhealthy, triggering rollback"
                ./enhanced-rollback.sh -a myapp -n production --strategy canary
              fi
            volumeMounts:
            - name: scripts
              mountPath: /scripts
          volumes:
          - name: scripts
            configMap:
              name: rollback-scripts
          restartPolicy: OnFailure
```

## 8. 故障排除

### 8.1 常见问题

1. **kubectl命令失败**: 检查KUBECONFIG配置和集群连接
2. **健康检查超时**: 检查应用响应时间和网络连接
3. **回滚脚本权限问题**: 确保脚本具有执行权限

### 8.2 日志查看

```bash
# 查看回滚操作日志
kubectl logs -n production -l app=myapp

# 查看通知日志
cat /tmp/rollback-notifications.log
```

### 8.3 调试模式

在执行脚本时添加 `-x` 参数可以查看详细的执行过程：

```bash
bash -x ./enhanced-rollback.sh -a myapp -n production
```

## 9. 安全考虑

1. **权限控制**: 确保只有授权人员可以执行回滚操作
2. **配置文件保护**: 保护包含敏感信息的配置文件
3. **审计日志**: 记录所有回滚操作的日志
4. **通知安全**: 确保通知渠道的安全性

通过以上增强的回滚机制，可以大大提高系统的可靠性和稳定性，在出现问题时快速恢复服务。