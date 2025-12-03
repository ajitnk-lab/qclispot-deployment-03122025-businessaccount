#!/bin/bash
# Quick Download and Deploy Script for Amazon Q CLI + VS Code Spot Instance
# Downloads core files from S3 and deploys the stack

set -e

BUCKET="03-july-2025-qclvscodespot-4.14pm"
REGION="us-west-2"

echo "🚀 Amazon Q CLI + VS Code Spot Instance Deployment"
echo "=================================================="
echo "📥 Downloading core files from S3..."

# Create deployment directory
mkdir -p qcli-vscode-deployment
cd qcli-vscode-deployment

# Download all core files
aws s3 cp s3://${BUCKET}/ . --recursive --region ${REGION}

echo "✅ Downloaded $(ls -1 | wc -l) files"
echo "📋 Files downloaded:"
ls -la

# Make scripts executable
chmod +x cfn-deployment-script.sh user-data-script-s3copy.sh

echo ""
echo "🎯 Ready to deploy!"
echo "To deploy the stack, run:"
echo "  ./cfn-deployment-script.sh"
echo ""
echo "📁 All files are ready in: $(pwd)"
