#!/bin/bash
set -e

# Amazon Q CLI V10 - US-WEST-2A ONLY (FIXED) Deployment Script
# 8 Launch Configurations in SINGLE AZ ONLY with persistent volumes

REGION="us-west-2"
STACK_NAME="amazon-q-cli-uswest2a-fixed-$(date +%d%b%Y | tr '[:upper:]' '[:lower:]')"
TEMPLATE_FILE="uswest2a-only-template.yaml"
KEY_NAME="amazon-q-key-uswest2"

echo "=============================================="
echo "🚀 Amazon Q CLI - US-WEST-2A ONLY (FIXED)"
echo "   8 Instance Types | SINGLE AZ | Persistent Volumes"
echo "=============================================="
echo
echo "Stack Name: $STACK_NAME"
echo "Template: $TEMPLATE_FILE"
echo "Region: $REGION"
echo "AZ: us-west-2a ONLY"
echo
read -p "Deploy FIXED us-west-2a only stack? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 0
fi

echo "🚀 Deploying FIXED stack..."
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body "file://$TEMPLATE_FILE" \
    --parameters \
        ParameterKey=KeyName,ParameterValue=$KEY_NAME \
        ParameterKey=SpotPriceM5,ParameterValue=0.400 \
        ParameterKey=SpotPriceM6i,ParameterValue=0.350 \
        ParameterKey=SpotPriceC5,ParameterValue=0.300 \
        ParameterKey=SpotPriceC6i,ParameterValue=0.280 \
        ParameterKey=SpotPriceR5,ParameterValue=0.450 \
        ParameterKey=SpotPriceR6i,ParameterValue=0.400 \
        ParameterKey=SpotPriceT3,ParameterValue=0.200 \
        ParameterKey=SpotPriceM6a,ParameterValue=0.320 \
    --capabilities CAPABILITY_IAM \
    --region "$REGION"

echo "✅ FIXED stack deployment initiated: $STACK_NAME"
echo "This will deploy ALL 8 instance types in us-west-2a ONLY"
