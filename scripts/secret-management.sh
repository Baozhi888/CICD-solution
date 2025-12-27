#!/bin/bash

# Secret Management Best Practices Script
# This script demonstrates best practices for handling sensitive information in CI/CD

set -euo pipefail

# 安全删除函数：使用 shred 彻底清除敏感文件
# shred 会多次覆写文件内容，防止数据恢复
secure_delete() {
  local target="$1"

  if [[ -d "$target" ]]; then
    # 递归安全删除目录中的所有文件
    find "$target" -type f -exec shred -vfz -n 3 {} \; 2>/dev/null || true
    rm -rf "$target"
  elif [[ -f "$target" ]]; then
    # 安全删除单个文件
    shred -vfz -n 3 "$target" 2>/dev/null || rm -f "$target"
  fi
}

# 清理环境变量中的敏感信息
secure_unset_vars() {
  local vars=("DB_PASSWORD" "DB_USERNAME" "API_KEY" "VAULT_TOKEN" "APP_ENV_FILE")
  for var in "${vars[@]}"; do
    unset "$var" 2>/dev/null || true
  done
}

# Function to validate secret requirements
validate_secret_requirements() {
  echo "Validating secret requirements..."
  
  # Check if required environment variables are set
  local required_vars=("VAULT_ADDR" "KUBE_NAMESPACE")
  for var in "${required_vars[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      echo "Error: Required environment variable $var is not set"
      exit 1
    fi
  done
  
  echo "Secret requirements validation passed"
}

# Function to securely retrieve and handle secrets
secure_secret_handling() {
  echo "Securely handling secrets..."
  
  # Create a temporary directory for secrets with restricted permissions
  local temp_dir=$(mktemp -d)
  chmod 700 "$temp_dir"
  
  # Ensure cleanup on exit (使用安全删除)
  trap 'secure_delete "$temp_dir"; secure_unset_vars' EXIT
  
  # Retrieve secrets using Vault agent (assuming Vault agent sidecar)
  if [[ -f "/vault/secrets/db-password" ]]; then
    DB_PASSWORD=$(cat /vault/secrets/db-password)
  else
    echo "Error: Database password not found in Vault secrets"
    exit 1
  fi
  
  # Validate secret format (example: check if it's a valid password)
  if [[ ${#DB_PASSWORD} -lt 12 ]]; then
    echo "Error: Database password does not meet security requirements (minimum 12 characters)"
    exit 1
  fi
  
  # Use secrets only for the required operation, never log them
  echo "Secrets validated and ready for use"
}

# Function to securely pass secrets to applications
secure_secret_injection() {
  echo "Securely injecting secrets into application..."
  
  # Create a secure environment file (never commit this to version control)
  local env_file=$(mktemp)
  chmod 600 "$env_file"
  
  # Write secrets to the environment file
  cat > "$env_file" << EOF
DB_PASSWORD=$DB_PASSWORD
DB_USERNAME=$(cat /vault/secrets/db-username)
API_KEY=$(cat /vault/secrets/api-key)
EOF
  
  # Export the environment file path for the application to use
  export APP_ENV_FILE="$env_file"
  
  echo "Secrets securely injected"
}

# Function to demonstrate secure Kubernetes deployment
secure_k8s_deployment() {
  echo "Creating secure Kubernetes deployment..."
  
  # Create a Kubernetes secret from the environment file
  kubectl create secret generic app-secrets \
    --from-env-file="$APP_ENV_FILE" \
    --namespace="$KUBE_NAMESPACE" \
    --dry-run=client -o yaml | \
    kubectl apply -f -
  
  # Deploy the application with restricted permissions
  cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: $KUBE_NAMESPACE
spec:
  replicas: 3
  selector:
    matchLabels:
      app: secure-app
  template:
    metadata:
      labels:
        app: secure-app
    spec:
      serviceAccountName: cicd-service-account
      containers:
      - name: app
        image: myapp:latest
        envFrom:
        - secretRef:
            name: app-secrets
        securityContext:
          runAsNonRoot: true
          runAsUser: 1000
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
EOF
  
  echo "Secure deployment created"
}

# Main execution
main() {
  echo "Starting secure secret management process..."

  # 设置最终清理 trap
  trap 'secure_unset_vars; [[ -n "${APP_ENV_FILE:-}" ]] && secure_delete "$APP_ENV_FILE"' EXIT

  # Validate requirements
  validate_secret_requirements

  # Handle secrets securely
  secure_secret_handling

  # Inject secrets securely
  secure_secret_injection

  # Deploy securely to Kubernetes
  secure_k8s_deployment

  # 主动清理环境文件
  if [[ -n "${APP_ENV_FILE:-}" ]] && [[ -f "$APP_ENV_FILE" ]]; then
    echo "Cleaning up sensitive environment file..."
    secure_delete "$APP_ENV_FILE"
  fi

  # 清理环境变量
  secure_unset_vars

  echo "Secure secret management process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi