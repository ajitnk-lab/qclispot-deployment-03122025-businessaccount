#!/bin/bash

# Temporary deployment script for us-west-2a only CloudFormation template
# Usage: ./temp-deploy-usw2a-only.sh

set -e

STACK_NAME="amazon-q-cli-temp-usw2a-only-$(date +%d%b%Y-%H%M)"
TEMPLATE_FILE="temp-cfn-template-usw2a-only.yaml"
REGION="us-west-2"

echo "🚀 Deploying temporary CloudFormation stack for us-west-2a only..."
echo "Stack Name: $STACK_NAME"
echo "Template: $TEMPLATE_FILE"
echo "Region: $REGION"
echo ""

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "❌ Template file $TEMPLATE_FILE not found!"
    exit 1
fi

# Deploy the stack
echo "📦 Creating CloudFormation stack..."
aws cloudformation create-stack \
    --stack-name "$STACK_NAME" \
    --template-body file://"$TEMPLATE_FILE" \
    --capabilities CAPABILITY_IAM \
    --region "$REGION" \
    --parameters ParameterKey=KeyName,ParameterValue=amazon-q-key-uswest2 \
                 ParameterKey=SpotPriceM5,ParameterValue=0.600 \
                 ParameterKey=SpotPriceR5,ParameterValue=0.650

echo "⏳ Waiting for stack creation to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "✅ Stack created successfully!"
echo ""

# Get outputs
echo "📋 Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo "🎉 Temporary deployment complete!"
echo "Stack Name: $STACK_NAME"
echo "To delete: aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION"
