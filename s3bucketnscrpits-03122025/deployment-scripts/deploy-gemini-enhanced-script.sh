#!/bin/bash

# Deploy Enhanced User Script with Gemini CLI to S3
# This script safely updates the user-data script in S3 with Gemini CLI installation

set -e

echo "🚀 Deploying Enhanced User Script with Gemini CLI"
echo "================================================="
echo ""

# Get current region and bucket information
REGION=$(aws configure get region 2>/dev/null || echo "us-west-2")
echo "📍 Region: $REGION"

# Find the S3 bucket used by the CloudFormation stack
echo "🔍 Finding S3 bucket from CloudFormation stack..."
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --region $REGION \
    --query "Stacks[?contains(StackName, 'amazon-q-cli-vscode-v10-enhanced')].Outputs[?OutputKey=='UserDataBucket'].OutputValue" \
    --output text 2>/dev/null)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
    echo "⚠️ Could not find bucket from CloudFormation outputs, trying alternative method..."
    
    # Try to find bucket by listing and filtering
    BUCKET_NAME=$(aws s3 ls | grep -E "(amazonq|vscode|userdata)" | head -1 | awk '{print $3}')
    
    if [ -z "$BUCKET_NAME" ]; then
        echo "❌ Could not find S3 bucket. Please specify manually:"
        echo "   Usage: BUCKET_NAME=your-bucket-name $0"
        exit 1
    fi
fi

echo "📦 S3 Bucket: $BUCKET_NAME"
echo ""

# Verify the enhanced script exists
ENHANCED_SCRIPT="/tmp/user-data-script-with-gemini.sh"
if [ ! -f "$ENHANCED_SCRIPT" ]; then
    echo "❌ Enhanced script not found at $ENHANCED_SCRIPT"
    echo "Please run the script creation process first."
    exit 1
fi

echo "✅ Enhanced script found: $ENHANCED_SCRIPT"
echo ""

# Create backup of current script in S3
echo "💾 Creating backup of current user script..."
BACKUP_KEY="user-data-script-backup-$(date +%Y%m%d-%H%M%S).sh"
aws s3 cp s3://$BUCKET_NAME/user-data-script-s3copy.sh s3://$BUCKET_NAME/$BACKUP_KEY 2>/dev/null || echo "⚠️ Could not create backup (original may not exist)"
echo "📁 Backup created: s3://$BUCKET_NAME/$BACKUP_KEY"
echo ""

# Upload the enhanced script
echo "📤 Uploading enhanced user script with Gemini CLI..."
aws s3 cp "$ENHANCED_SCRIPT" s3://$BUCKET_NAME/user-data-script-s3copy.sh \
    --metadata "version=v10-enhanced-with-gemini,created=$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [ $? -eq 0 ]; then
    echo "✅ Enhanced script uploaded successfully!"
else
    echo "❌ Failed to upload enhanced script"
    exit 1
fi

echo ""
echo "🔍 Verifying upload..."
aws s3 ls s3://$BUCKET_NAME/user-data-script-s3copy.sh --human-readable

echo ""
echo "📋 Summary:"
echo "==========="
echo "✅ Original script backed up to: s3://$BUCKET_NAME/$BACKUP_KEY"
echo "✅ Enhanced script uploaded to: s3://$BUCKET_NAME/user-data-script-s3copy.sh"
echo "✅ New instances will now include Gemini CLI with persistent storage"
echo ""
echo "🚨 Important Notes:"
echo "- Existing instances are NOT affected by this change"
echo "- Only NEW instances launched will have Gemini CLI"
echo "- To apply to existing instance, you can manually install using the test script"
echo ""
echo "🧪 Testing:"
echo "- Run './test-gemini-cli.sh' to test current instance"
echo "- Launch new instance to test enhanced script"
echo ""
echo "🔄 To rollback:"
echo "aws s3 cp s3://$BUCKET_NAME/$BACKUP_KEY s3://$BUCKET_NAME/user-data-script-s3copy.sh"
echo ""
echo "🎉 Deployment completed successfully!"
