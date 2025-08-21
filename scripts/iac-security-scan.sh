#!/bin/bash

# Infrastructure as Code (IaC) Security Scanning Script
# This script demonstrates how to implement IaC security scanning in CI/CD

set -euo pipefail

# Function to scan Kubernetes manifests with Kubeaudit
scan_k8s_manifests_kubeaudit() {
  echo "Scanning Kubernetes manifests with Kubeaudit..."
  
  # Check if Kubernetes manifests directory exists
  if [[ ! -d "k8s" ]]; then
    echo "Warning: k8s directory not found"
    return 0
  fi
  
  # Install Kubeaudit if not already installed
  if ! command -v kubeaudit &> /dev/null; then
    echo "Installing Kubeaudit..."
    # Note: In a real pipeline, you would download the appropriate version
    echo "Note: In a real pipeline, you would install Kubeaudit properly"
    return 0
  fi
  
  # Run Kubeaudit on all Kubernetes manifests
  echo "Running Kubeaudit scan..."
  kubeaudit -f k8s/ all
  
  echo "Kubeaudit scan completed"
}

# Function to scan Kubernetes manifests with Checkov
scan_k8s_manifests_checkov() {
  echo "Scanning Kubernetes manifests with Checkov..."
  
  # Check if Kubernetes manifests directory exists
  if [[ ! -d "k8s" ]]; then
    echo "Warning: k8s directory not found"
    return 0
  fi
  
  # Install Checkov if not already installed
  if ! command -v checkov &> /dev/null; then
    echo "Installing Checkov..."
    pip install checkov
  fi
  
  # Run Checkov scan on Kubernetes manifests
  echo "Running Checkov scan..."
  checkov --directory k8s/ --framework kubernetes
  
  echo "Checkov scan completed"
}

# Function to scan Dockerfiles with Dockle
scan_dockerfiles_dockle() {
  echo "Scanning Dockerfiles with Dockle..."
  
  # Find all Dockerfiles in the repository
  mapfile -t dockerfiles < <(find . -name "Dockerfile*" -type f)
  
  # Check if any Dockerfiles were found
  if [[ ${#dockerfiles[@]} -eq 0 ]]; then
    echo "Warning: No Dockerfiles found"
    return 0
  fi
  
  # Install Dockle if not already installed
  if ! command -v dockle &> /dev/null; then
    echo "Installing Dockle..."
    # Note: In a real pipeline, you would download the appropriate version
    echo "Note: In a real pipeline, you would install Dockle properly"
    return 0
  fi
  
  # Run Dockle scan on each Dockerfile
  for dockerfile in "${dockerfiles[@]}"; do
    echo "Scanning $dockerfile..."
    dockle --input "$dockerfile"
  done
  
  echo "Dockle scan completed"
}

# Function to scan Terraform files with TFSec
scan_terraform_tfsec() {
  echo "Scanning Terraform files with TFSec..."
  
  # Check if Terraform files exist
  if ! find . -name "*.tf" -type f | grep -q .; then
    echo "Warning: No Terraform files found"
    return 0
  fi
  
  # Install TFSec if not already installed
  if ! command -v tfsec &> /dev/null; then
    echo "Installing TFSec..."
    # Note: In a real pipeline, you would download the appropriate version
    echo "Note: In a real pipeline, you would install TFSec properly"
    return 0
  fi
  
  # Run TFSec scan
  echo "Running TFSec scan..."
  tfsec .
  
  echo "TFSec scan completed"
}

# Function to generate IaC security report
generate_iac_report() {
  echo "Generating IaC security report..."
  
  # Create a report directory
  mkdir -p iac-security-reports
  
  # Generate report summary
  cat > iac-security-reports/summary.txt << EOF
IaC Security Scan Report
========================

Scan Date: $(date)
Repository: $(basename "$(pwd)")

Scanned Components:
- Kubernetes Manifests: $( [[ -d "k8s" ]] && echo "Yes" || echo "No" )
- Dockerfiles: $( find . -name "Dockerfile*" -type f | wc -l )
- Terraform Files: $( find . -name "*.tf" -type f | wc -l )

Findings Summary:
- Critical Issues: TBD
- High Issues: TBD
- Medium Issues: TBD
- Low Issues: TBD

Recommendations:
1. Address all critical and high severity issues immediately
2. Review medium severity issues for potential improvements
3. Implement security scanning as part of CI/CD pipeline
4. Regularly update IaC scanning tools to latest versions
EOF
  
  echo "IaC security report generated in iac-security-reports/"
}

# Main execution
main() {
  echo "Starting IaC security scanning process..."
  
  # Scan Kubernetes manifests
  scan_k8s_manifests_kubeaudit
  scan_k8s_manifests_checkov
  
  # Scan Dockerfiles
  scan_dockerfiles_dockle
  
  # Scan Terraform files
  scan_terraform_tfsec
  
  # Generate IaC security report
  generate_iac_report
  
  echo "IaC security scanning process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi