#!/bin/bash

# Vault Integration Script for CI/CD Pipeline
# This script demonstrates how to integrate HashiCorp Vault with your CI/CD pipeline

set -e

# Function to authenticate with Vault using Kubernetes auth
vault_auth_kubernetes() {
  echo "Authenticating with Vault using Kubernetes auth method..."
  
  # Get the JWT token from the service account
  JWT_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
  
  # Authenticate with Vault
  VAULT_RESPONSE=$(curl -s --request POST \
    --data "{\"jwt\": \"$JWT_TOKEN\", \"role\": \"app-role\"}" \
    ${VAULT_ADDR}/v1/auth/kubernetes/login)
  
  # Extract the client token
  CLIENT_TOKEN=$(echo $VAULT_RESPONSE | jq -r '.auth.client_token')
  
  # Export the token for subsequent Vault commands
  export VAULT_TOKEN=$CLIENT_TOKEN
  
  echo "Successfully authenticated with Vault"
}

# Function to retrieve secrets from Vault
vault_get_secret() {
  local secret_path=$1
  local secret_key=$2
  
  echo "Retrieving secret from path: $secret_path"
  
  # Get the secret from Vault
  SECRET_VALUE=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
    ${VAULT_ADDR}/v1/$secret_path | jq -r ".data.data.$secret_key")
  
  echo "$SECRET_VALUE"
}

# Function to inject secrets into environment variables
inject_secrets_to_env() {
  echo "Injecting secrets into environment variables..."
  
  # Example: Get database credentials
  export DB_PASSWORD=$(vault_get_secret "secret/data/myapp/database" "password")
  export DB_USERNAME=$(vault_get_secret "secret/data/myapp/database" "username")
  
  # Example: Get API keys
  export API_KEY=$(vault_get_secret "secret/data/myapp/api" "key")
  
  echo "Secrets successfully injected into environment"
}

# Function to use secrets in application configuration
create_app_config() {
  echo "Creating application configuration with secrets..."
  
  # Create a configuration file with secrets
  cat > app-config.json << EOF
{
  "database": {
    "host": "db.example.com",
    "port": 5432,
    "username": "$DB_USERNAME",
    "password": "$DB_PASSWORD"
  },
  "api": {
    "key": "$API_KEY",
    "endpoint": "https://api.example.com"
  }
}
EOF
  
  echo "Application configuration created"
}

# Main execution
main() {
  echo "Starting Vault integration process..."
  
  # Authenticate with Vault
  vault_auth_kubernetes
  
  # Inject secrets into environment
  inject_secrets_to_env
  
  # Create application configuration
  create_app_config
  
  echo "Vault integration completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi