# **AWS SageMaker Studio + Local VS Code Setup Analysis**

## **🎯 What This Enables**
- Connect your **local VS Code** (with all your extensions, themes, settings) to **SageMaker Studio compute resources**
- Run ML workloads on scalable AWS infrastructure while maintaining your familiar local development environment
- Access SageMaker's managed Jupyter environments, GPU instances, and ML-optimized images from VS Code

## **📋 Prerequisites & Requirements**

### **Local Environment Requirements**
- **VS Code Version**: v1.90+ (latest stable recommended)
- **Operating System**: 
  - macOS 13+
  - Windows 10/11
  - Linux (official Microsoft VS Code, not open-source versions)
- **Extensions**: AWS Toolkit for Visual Studio Code

### **AWS Infrastructure Requirements**
- **SageMaker Domain**: Must be created and configured
- **SageMaker Studio Space**: Individual workspace within the domain
- **Instance Requirements**: Minimum 8GB memory (excludes ml.t3.medium, ml.c7i.large, etc.)
- **Image Requirements**: SageMaker Distribution v2.7+ (if using SageMaker Distribution)

## **🏗️ Detailed Setup Steps**

### **Phase 1: AWS Infrastructure Setup (Administrator)**

**1. Create SageMaker Domain**
```bash
# This requires AWS Console or CLI setup
# Domain provides the foundational infrastructure
```

**2. Configure IAM Permissions**
Three different permission sets depending on connection method:

**Method A: Deep Link Permissions** (Simplest)
- Attach to SageMaker execution role
- Allows "Open in VS Code" button from SageMaker UI

**Method B: AWS Toolkit Permissions** (Most Flexible)
- Attach to IAM user/role or IdC permission sets
- Enables browsing spaces from VS Code AWS Explorer

**Method C: SSH Terminal Permissions** (Most Control)
- Attach to local AWS credentials IAM identity
- Enables command-line SSH connections

### **Phase 2: Local VS Code Setup**

**1. Install Required Extensions**
```bash
# Install AWS Toolkit for Visual Studio Code
# Available from VS Code marketplace
```

**2. Configure AWS Authentication**
- **Option A**: AWS Builder ID
- **Option B**: IAM Identity Center (SSO)
- **Option C**: IAM Credentials (Access Key/Secret)

**3. Connect to AWS**
```bash
# Through VS Code Command Palette:
# Ctrl+Shift+P → "AWS: Add a New Connection"
```

### **Phase 3: SageMaker Space Configuration**

**1. Enable Remote Access**
```bash
# In SageMaker Studio UI:
# Navigate to Space → Toggle "Remote Access" ON → Start Space
```

**2. Choose Connection Method**

**Method 1: Deep Link (Easiest)**
```bash
# From SageMaker UI:
# Space → "Open space with" → "VS Code"
# Browser launches → Confirms connection
```

**Method 2: AWS Toolkit (Most Common)**
```bash
# From VS Code:
# AWS Explorer → SageMaker AI → Find Space → Click "Connect"
```

**Method 3: SSH Terminal (Advanced)**
```bash
# Configure SSH config file
# Use custom shell script for connection
# Direct terminal access
```

## **🔧 Technical Architecture**

### **Connection Flow**
```
Local VS Code ←→ AWS Toolkit Extension ←→ SageMaker Session Manager ←→ SageMaker Space
```

### **Security Model**
- **Secure tunnel** through AWS Session Manager
- **IAM-based authentication** and authorization
- **VPC isolation** (if configured)
- **No direct internet exposure** of compute resources

### **Resource Management**
- **Compute**: Runs on SageMaker managed instances
- **Storage**: Persistent EFS storage attached to spaces
- **Networking**: AWS-managed secure connections

## **💰 Cost Implications**

### **Compute Costs**
- **SageMaker Studio instances**: Pay per hour when running
- **Minimum instance**: ml.t3.large (~$0.0464/hour)
- **GPU instances**: ml.g4dn.xlarge (~$0.736/hour)

### **Storage Costs**
- **EFS storage**: ~$0.30/GB/month for space storage
- **Data transfer**: Minimal for remote VS Code connections

## **🚫 What You DON'T Need to Change**

### **Your Current Spot Instance Setup**
- **No changes needed** to your existing EC2 spot instance
- **VS Code Server remains intact** - this is a separate connection
- **Can run both simultaneously** - local VS Code can connect to both:
  - Your spot instance (via Remote SSH)
  - SageMaker Studio (via AWS Toolkit)

### **Your Local VS Code**
- **Same VS Code installation** handles both connections
- **Extensions work** with both remote environments
- **Settings sync** across all remote connections

## **🔄 Workflow Integration**

### **Typical Usage Pattern**
```bash
# Development workflow:
1. Local VS Code → SageMaker Studio (for ML experimentation)
2. Local VS Code → Spot Instance (for general development)
3. Switch between connections as needed
```

### **Extension Compatibility**
- **Most extensions work** with SageMaker remote connection
- **AI/ML extensions** particularly beneficial (Python, Jupyter, etc.)
- **Some extensions** may not work (GUI-dependent, architecture-specific)

## **⚡ Quick Start Summary**

**For You (End User):**
1. Install AWS Toolkit extension in local VS Code
2. Configure AWS authentication (Builder ID/IAM)
3. Request SageMaker domain access from AWS admin
4. Connect via AWS Explorer → SageMaker AI → Your Space

**For AWS Admin (if you're admin):**
1. Create SageMaker domain
2. Create user profile and space
3. Configure IAM permissions for remote access
4. Enable remote access on spaces

## **🎯 Key Benefits for Your Use Case**

- **Scalable compute**: Access GPU/high-memory instances on-demand
- **ML-optimized environment**: Pre-configured with ML frameworks
- **Cost efficiency**: Pay only when using compute resources
- **Familiar interface**: Keep your VS Code setup and extensions
- **Parallel workflows**: Use both spot instance and SageMaker simultaneously

## **📚 Detailed IAM Permission Examples**

### **Method A: Deep Link Permissions**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "RestrictStartSessionOnSpacesToUserProfile",
            "Effect": "Allow",
            "Action": [
                "sagemaker:StartSession"
            ],
            "Resource": "arn:*:sagemaker:*:*:space/${sagemaker:DomainId}/*",
            "Condition": {
                "ArnLike": {
                    "sagemaker:ResourceTag/sagemaker:user-profile-arn": "arn:aws:sagemaker:*:*:user-profile/${sagemaker:DomainId}/${sagemaker:UserProfileName}"
                }
            }
        }
    ]
}
```

### **Method B: AWS Toolkit Permissions**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "sagemaker:ListSpaces",
                "sagemaker:DescribeSpace",
                "sagemaker:UpdateSpace",
                "sagemaker:ListApps",
                "sagemaker:CreateApp",
                "sagemaker:DeleteApp",
                "sagemaker:DescribeApp",
                "sagemaker:StartSession",
                "sagemaker:DescribeDomain",
                "sagemaker:AddTags"
            ],
            "Resource": "*"
        }
    ]
}
```

### **Method C: SSH Terminal Permissions**
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "sagemaker:StartSession",
            "Resource": "*"
        }
    ]
}
```

## **🔧 SSH Configuration Example**

### **Shell Script for SSH Connection**
```bash
#!/bin/bash
# File: /home/user/sagemaker_connect.sh
set -exuo pipefail

SPACE_ARN="$1"
AWS_PROFILE="${2:-}"

# Validate ARN and extract region
if [[ "$SPACE_ARN" =~ ^arn:aws[-a-z]*:sagemaker:([a-z0-9-]+):[0-9]{12}:space\/[^\/]+\/[^\/]+$ ]]; then
    AWS_REGION="${BASH_REMATCH[1]}"
else
    echo "Error: Invalid SageMaker Studio Space ARN format."
    exit 1
fi

# Optional profile flag
PROFILE_ARG=()
if [[ -n "$AWS_PROFILE" ]]; then
    PROFILE_ARG=(--profile "$AWS_PROFILE")
fi

# Start session
START_SESSION_JSON=$(aws sagemaker start-session \
    --resource-identifier "$SPACE_ARN" \
    --region "${AWS_REGION}" \
    "${PROFILE_ARG[@]}")

# Extract fields using grep and sed
SESSION_ID=$(echo "$START_SESSION_JSON" | grep -o '"SessionId": "[^"]*"' | sed 's/.*: "//;s/"$//')
STREAM_URL=$(echo "$START_SESSION_JSON" | grep -o '"StreamUrl": "[^"]*"' | sed 's/.*: "//;s/"$//')
TOKEN=$(echo "$START_SESSION_JSON" | grep -o '"TokenValue": "[^"]*"' | sed 's/.*: "//;s/"$//')

# Validate extracted values
if [[ -z "$SESSION_ID" || -z "$STREAM_URL" || -z "$TOKEN" ]]; then
    echo "Error: Failed to extract session information from sagemaker start session response."
    exit 1
fi

# Call session-manager-plugin
session-manager-plugin \
    "{\"streamUrl\":\"$STREAM_URL\",\"tokenValue\":\"$TOKEN\",\"sessionId\":\"$SESSION_ID\"}" \
    "$AWS_REGION" "StartSession"
```

### **SSH Config Entry**
```bash
# File: $HOME/.ssh/config
Host my_space_name_abc
  HostName 'arn:PARTITION:sagemaker:REGION:ACCOUNT:space/DOMAIN_ID/space_name_abc'
  ProxyCommand '/home/user/sagemaker_connect.sh' '%h'
  ForwardAgent yes
  AddKeysToAgent yes
  StrictHostKeyChecking accept-new
```

## **📝 Important Notes**

- **Extension Compatibility**: Not all VS Code extensions work with remote development. Extensions requiring local GUI components or specific client-server interactions may not function properly.
- **Network Requirements**: Ensure your local machine can reach AWS endpoints for Session Manager connectivity.
- **Cost Monitoring**: Set up billing alerts as SageMaker compute costs can accumulate quickly with larger instances.
- **Security**: Use least-privilege IAM policies in production environments rather than the broad `"Resource": "*"` examples shown for testing.

The setup is **complementary** to your existing spot instance + VS Code Server setup, not a replacement. You'll have the flexibility to choose the right environment for each task!
