#!/bin/bash
# Quick Deploy Script for Amazon Q CLI + VS Code Spot Instance
# Downloads core files from S3 and deploys the CloudFormation stack
# 
# Usage: ./quick-deploy-qcli-vscode.sh
#
# This script will:
# 1. Download the deployment package from S3
# 2. Set up the deployment environment
# 3. Launch the CloudFormation stack deployment

set -e

# Configuration
BUCKET="03-july-2025-qclvscodespot-4.14pm"
REGION="us-west-2"
DEPLOYMENT_DIR="qcli-vscode-deployment-$(date +%Y%m%d-%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

# Header
echo -e "${BLUE}"
echo "🚀 Amazon Q CLI + VS Code Spot Instance - Quick Deploy"
echo "======================================================"
echo -e "${NC}"

# Check prerequisites
log "🔍 Checking prerequisites..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    error "AWS CLI is not installed. Please install AWS CLI first."
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    error "AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

success "Prerequisites check passed"

# Create deployment directory
log "📁 Creating deployment directory: $DEPLOYMENT_DIR"
mkdir -p "$DEPLOYMENT_DIR"
cd "$DEPLOYMENT_DIR"

# Download deployment package
log "📥 Downloading deployment package from S3..."
log "   Bucket: s3://$BUCKET/"
log "   Region: $REGION"

if aws s3 cp "s3://$BUCKET/" . --recursive --region "$REGION"; then
    success "Downloaded deployment package successfully"
else
    error "Failed to download deployment package from S3"
    exit 1
fi

# Show downloaded files
log "📋 Downloaded files:"
ls -la

# Make scripts executable
log "🔧 Setting executable permissions..."
chmod +x cfn-deployment-script.sh user-data-script-s3copy.sh 2>/dev/null || true

if [ -f "download-and-deploy.sh" ]; then
    chmod +x download-and-deploy.sh
fi

success "Permissions set successfully"

# Verify core files exist
log "✅ Verifying core deployment files..."
REQUIRED_FILES=("qclivscode-cfn_template.yaml" "cfn-deployment-script.sh" "user-data-script-s3copy.sh" "amazon-q-key-uswest2.pem")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        success "Found: $file"
    else
        error "Missing required file: $file"
        exit 1
    fi
done

# Show deployment summary
echo ""
log "🎯 Deployment Summary:"
echo "   📁 Deployment Directory: $(pwd)"
echo "   📦 CloudFormation Template: qclivscode-cfn_template.yaml"
echo "   🚀 Deployment Script: cfn-deployment-script.sh"
echo "   📜 UserData Script: user-data-script-s3copy.sh"
echo "   🔑 SSH Key: amazon-q-key-uswest2.pem"
echo ""

# Ask for confirmation
echo -e "${YELLOW}🤔 Ready to deploy the Amazon Q CLI + VS Code Spot Instance stack?${NC}"
echo "   This will create AWS resources and may incur costs."
echo ""
read -p "Do you want to proceed with deployment? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "🚀 Starting CloudFormation stack deployment..."
    echo ""
    
    # Run the deployment script
    if ./cfn-deployment-script.sh; then
        echo ""
        success "🎉 Deployment completed successfully!"
        echo ""
        log "📋 Next Steps:"
        echo "   1. Check the deployment output above for access information"
        echo "   2. Wait 5-10 minutes for instance setup to complete"
        echo "   3. Access VS Code Server via the provided URL"
        echo "   4. SSH to the instance using the provided command"
        echo ""
        log "📁 Deployment files are available in: $(pwd)"
    else
        error "Deployment failed. Check the output above for details."
        exit 1
    fi
else
    warning "Deployment cancelled by user"
    log "📁 Deployment files are ready in: $(pwd)"
    log "🚀 To deploy later, run: ./cfn-deployment-script.sh"
fi

echo ""
success "Quick deploy script completed"
