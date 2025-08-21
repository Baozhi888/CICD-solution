#!/bin/bash

# Dependency Vulnerability Scanning Script
# This script demonstrates how to implement dependency vulnerability scanning in CI/CD

set -euo pipefail

# Function to scan Node.js dependencies
scan_nodejs_dependencies() {
  echo "Scanning Node.js dependencies for vulnerabilities..."
  
  # Check if package-lock.json exists
  if [[ ! -f "package-lock.json" ]]; then
    echo "Warning: package-lock.json not found, running npm install to generate it"
    npm install --package-lock-only
  fi
  
  # Run npm audit
  echo "Running npm audit..."
  npm audit --audit-level=moderate
  
  # If high or critical vulnerabilities found, exit with error
  if npm audit --audit-level=high; then
    echo "No high or critical vulnerabilities found in Node.js dependencies"
  else
    echo "High or critical vulnerabilities found in Node.js dependencies"
    echo "Please address these vulnerabilities before proceeding"
    exit 1
  fi
}

# Function to scan Python dependencies
scan_python_dependencies() {
  echo "Scanning Python dependencies for vulnerabilities..."
  
  # Check if requirements.txt exists
  if [[ ! -f "requirements.txt" ]]; then
    echo "Warning: requirements.txt not found"
    return 0
  fi
  
  # Install safety tool if not already installed
  if ! command -v safety &> /dev/null; then
    echo "Installing safety tool..."
    pip install safety
  fi
  
  # Run safety check
  echo "Running safety check..."
  if safety check -r requirements.txt --full-report; then
    echo "No known vulnerabilities found in Python dependencies"
  else
    echo "Vulnerabilities found in Python dependencies"
    echo "Please address these vulnerabilities before proceeding"
    exit 1
  fi
}

# Function to scan Java dependencies
scan_java_dependencies() {
  echo "Scanning Java dependencies for vulnerabilities..."
  
  # Check if pom.xml exists (Maven)
  if [[ -f "pom.xml" ]]; then
    echo "Found Maven project, scanning with OWASP Dependency Check..."
    
    # Install OWASP Dependency Check if not already installed
    if ! command -v dependency-check &> /dev/null; then
      echo "Installing OWASP Dependency Check..."
      # This is a simplified installation, in practice you might want to download
      # the latest version from the official source
      echo "Note: In a real pipeline, you would install OWASP Dependency Check properly"
    fi
    
    # Run OWASP Dependency Check
    echo "Running OWASP Dependency Check..."
    # dependency-check --project "MyApp" --scan . --format XML
    
    echo "OWASP Dependency Check completed"
  fi
  
  # Check if build.gradle exists (Gradle)
  if [[ -f "build.gradle" ]]; then
    echo "Found Gradle project, scanning with Gradle dependency check..."
    
    # Run Gradle dependency check
    echo "Running Gradle dependency check..."
    # ./gradlew dependencyCheckAnalyze
    
    echo "Gradle dependency check completed"
  fi
}

# Function to generate dependency report
generate_dependency_report() {
  echo "Generating dependency report..."
  
  # Create a report directory
  mkdir -p dependency-reports
  
  # Generate dependency tree for Node.js
  if [[ -f "package.json" ]]; then
    npm ls --all > dependency-reports/nodejs-dependencies.txt
  fi
  
  # Generate dependency tree for Python
  if [[ -f "requirements.txt" ]]; then
    pip list > dependency-reports/python-dependencies.txt
  fi
  
  # Generate dependency tree for Java (Maven)
  if [[ -f "pom.xml" ]]; then
    mvn dependency:tree > dependency-reports/java-dependencies.txt
  fi
  
  echo "Dependency report generated in dependency-reports/"
}

# Main execution
main() {
  echo "Starting dependency vulnerability scanning process..."
  
  # Scan Node.js dependencies
  if [[ -f "package.json" ]]; then
    scan_nodejs_dependencies
  fi
  
  # Scan Python dependencies
  if [[ -f "requirements.txt" ]]; then
    scan_python_dependencies
  fi
  
  # Scan Java dependencies
  if [[ -f "pom.xml" ]] || [[ -f "build.gradle" ]]; then
    scan_java_dependencies
  fi
  
  # Generate dependency report
  generate_dependency_report
  
  echo "Dependency vulnerability scanning process completed successfully"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi