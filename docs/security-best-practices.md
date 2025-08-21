# CI/CD安全最佳实践指南

## 1. 密钥管理

### 1.1 外部密钥管理服务集成

#### HashiCorp Vault集成示例

1. **Vault Agent配置** (`vault-config.yaml`):
   ```yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: vault-agent
   spec:
     template:
       spec:
         serviceAccountName: vault-sa
         containers:
         - name: vault-agent
           image: hashicorp/vault:latest
           env:
           - name: VAULT_ADDR
             value: "http://vault:8200"
           volumeMounts:
           - name: vault-config
             mountPath: /vault/config
   ```

2. **Vault集成脚本** (`vault-integration.sh`):
   ```bash
   #!/bin/bash
   # Authenticate with Vault using Kubernetes auth
   vault_auth_kubernetes() {
     JWT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
     VAULT_RESPONSE=$(curl -s --request POST \
       --data "{\"jwt\": \"$JWT_TOKEN\", \"role\": \"app-role\"}" \
       ${VAULT_ADDR}/v1/auth/kubernetes/login)
     CLIENT_TOKEN=$(echo $VAULT_RESPONSE | jq -r '.auth.client_token')
     export VAULT_TOKEN=$CLIENT_TOKEN
   }
   ```

### 1.2 更安全的Kubernetes认证方式

1. **创建专用服务账户**:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: cicd-service-account
     namespace: cicd
   ```

2. **配置RBAC权限**:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: cicd
     name: cicd-role
   rules:
   - apiGroups: [""]
     resources: ["pods", "services", "configmaps", "secrets"]
     verbs: ["get", "list", "create", "update", "patch", "delete"]
   ```

### 1.3 敏感信息处理最佳实践

1. **安全的密钥处理脚本** (`secret-management.sh`):
   ```bash
   # Create a temporary directory for secrets with restricted permissions
   temp_dir=$(mktemp -d)
   chmod 700 "$temp_dir"
   trap 'rm -rf "$temp_dir"' EXIT
   
   # Retrieve secrets using Vault agent
   if [[ -f "/vault/secrets/db-password" ]]; then
     DB_PASSWORD=$(cat /vault/secrets/db-password)
   fi
   ```

## 2. 权限最小化

### 2.1 Kubernetes专用服务账户

1. **为不同环境创建专用服务账户**:
   ```yaml
   apiVersion: v1
   kind: ServiceAccount
   metadata:
     name: cicd-deployer
     namespace: production
     annotations:
       eks.amazonaws.com/role-arn: arn:aws:iam::123456789012:role/production-cicd-role
   ```

### 2.2 RBAC细粒度权限控制

1. **为CI/CD部署者创建细粒度角色**:
   ```yaml
   apiVersion: rbac.authorization.k8s.io/v1
   kind: Role
   metadata:
     namespace: production
     name: cicd-deployer-role
   rules:
   - apiGroups: ["apps"]
     resources: ["deployments"]
     verbs: ["get", "list", "create", "update", "patch", "delete"]
   - apiGroups: [""]
     resources: ["secrets"]
     resourceNames: ["app-secrets"]
     verbs: ["get", "update", "patch"]
   ```

### 2.3 命名空间隔离策略

1. **创建隔离的命名空间**:
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: production
     labels:
       name: production
       environment: production
   ```

2. **为命名空间配置资源配额**:
   ```yaml
   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: prod-resource-quota
     namespace: production
   spec:
     hard:
       requests.cpu: "10"
       requests.memory: 20Gi
       limits.cpu: "20"
       limits.memory: 40Gi
   ```

## 3. 安全扫描增强

### 3.1 容器镜像安全扫描

1. **使用Trivy进行容器安全扫描**:
   ```yaml
   - name: Run Trivy vulnerability scanner
     uses: aquasecurity/trivy-action@master
     with:
       image-ref: 'docker.io/myapp:latest'
       format: 'sarif'
       output: 'trivy-results.sarif'
       severity: 'CRITICAL,HIGH'
   ```

### 3.2 依赖项漏洞扫描

1. **Node.js依赖扫描**:
   ```bash
   # Run npm audit
   npm audit --audit-level=high
   ```

2. **Python依赖扫描**:
   ```bash
   # Install and run safety tool
   pip install safety
   safety check -r requirements.txt --full-report
   ```

### 3.3 基础设施即代码(IaC)安全扫描

1. **使用Checkov扫描Kubernetes配置**:
   ```bash
   checkov --directory k8s/ --framework kubernetes
   ```

2. **使用Kubeaudit扫描安全配置**:
   ```bash
   kubeaudit -f k8s/ all
   ```

## 4. 安全配置示例

### 4.1 安全的Kubernetes部署配置

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: production
spec:
  template:
    spec:
      serviceAccountName: cicd-deployer
      containers:
      - name: app
        image: myapp:latest
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        envFrom:
        - secretRef:
            name: app-secrets
```

### 4.2 安全的CI/CD流水线配置

```yaml
jobs:
  container-security-scan:
    name: Container Security Scan
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'docker.io/myapp:latest'
          severity: 'CRITICAL,HIGH'
```

## 5. 监控和合规

### 5.1 安全扫描结果监控

1. **集成安全扫描结果到GitHub Security tab**:
   ```yaml
   - name: Upload Trivy scan results to GitHub Security tab
     uses: github/codeql-action/upload-sarif@v2
     with:
       sarif_file: 'trivy-results.sarif'
   ```

### 5.2 定期安全评估

1. **配置定期安全扫描**:
   ```yaml
   on:
     schedule:
       # Run security scans weekly
       - cron: '0 2 * * 1'
   ```

## 6. 最佳实践总结

1. **密钥管理**:
   - 永远不要在代码中硬编码密钥
   - 使用专用密钥管理服务
   - 定期轮换密钥

2. **权限控制**:
   - 遵循最小权限原则
   - 为不同环境使用不同的服务账户
   - 定期审查RBAC权限

3. **安全扫描**:
   - 在CI/CD流水线中集成多种安全扫描工具
   - 设置安全门禁，阻止高危漏洞的部署
   - 定期更新扫描工具和规则

4. **监控和响应**:
   - 集成安全扫描结果到开发平台
   - 建立安全事件响应流程
   - 定期进行安全评估和渗透测试