#!/bin/bash

# Amazon Q CLI Spot Fleet V10 Enhanced - Fixed IAM Timing Deployment Script
# This script deploys the fixed CloudFormation template with IAM dependency resolution

set -e

# Configuration
STACK_NAME="amazon-q-cli-vscode-v10-fixed-$(date +%d%b%Y)"
TEMPLATE_FILE="qclivscode-cfn_template-fixed.yaml"
REGION="us-west-2"
KEY_NAME="amazon-q-key-uswest2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if template file exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    error "Template file $TEMPLATE_FILE not found!"
    exit 1
fi

# Check if key pair exists
log "Checking if key pair $KEY_NAME exists..."
if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" --region "$REGION" >/dev/null 2>&1; then
    error "Key pair $KEY_NAME not found in region $REGION"
    exit 1
fi
success "Key pair $KEY_NAME found"

# Check for existing stack
log "Checking for existing stacks..."
EXISTING_STACKS=$(aws cloudformation list-stacks \
    --region "$REGION" \
    --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE \
    --query "StackSummaries[?contains(StackName, 'amazon-q-cli-vscode')].StackName" \
    --output text)

if [ ! -z "$EXISTING_STACKS" ]; then
    warning "Found existing Amazon Q CLI stacks:"
    echo "$EXISTING_STACKS"
    echo
    read -p "Do you want to continue with deployment? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Deployment cancelled by user"
        exit 0
    fi
fi

# Deploy the stack
log "Deploying CloudFormation stack: $STACK_NAME"
log "Template: $TEMPLATE_FILE"
log "Region: $REGION"

aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters ParameterKey=KeyName,ParameterValue="$KEY_NAME" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION" \
    --tags Key=Purpose,Value=AmazonQ-CLI-VSCode \
           Key=Version,Value=V10-ENHANCED-FIXED \
           Key=DeploymentDate,Value="$(date +%Y-%m-%d)" \
           Key=IAMFix,Value=DependsOn-Added

if [ $? -eq 0 ]; then
    success "Stack creation initiated successfully!"
    log "Stack Name: $STACK_NAME"
    
    # Monitor stack creation
    log "Monitoring stack creation progress..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
    
    if [ $? -eq 0 ]; then
        success "Stack created successfully!"
        
        # Get stack outputs
        log "Retrieving stack outputs..."
        OUTPUTS=$(aws cloudformation describe-stacks \
            --stack-name "$STACK_NAME" \
            --region "$REGION" \
            --query 'Stacks[0].Outputs')
        
        echo
        success "=== DEPLOYMENT COMPLETE ==="
        echo
        log "Stack Outputs:"
        echo "$OUTPUTS" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"'
        
        # Extract key information
        ELASTIC_IP=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ElasticIP") | .OutputValue')
        SSH_COMMAND=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="SSHCommand") | .OutputValue')
        VSCODE_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="VSCodeServerURL") | .OutputValue')
        
        echo
        success "=== QUICK ACCESS ==="
        log "Elastic IP: $ELASTIC_IP"
        log "SSH Command: $SSH_COMMAND"
        log "VS Code Server: $VSCODE_URL"
        echo
        success "=== IAM TIMING FIX APPLIED ==="
        log "✓ SpotFleet now waits for IAM Instance Profile completion"
        log "✓ Added 5-minute IAM credential availability check"
        log "✓ Enhanced error handling and retry mechanisms"
        
    else
        error "Stack creation failed!"
        log "Check the CloudFormation console for details"
        exit 1
    fi
else
    error "Failed to initiate stack creation!"
    exit 1
fi

log "Deployment script completed"
