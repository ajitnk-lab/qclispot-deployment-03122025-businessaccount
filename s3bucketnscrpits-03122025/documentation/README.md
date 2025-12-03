# Amazon Q CLI + Gemini Flash 2.5 Enhanced Deployment

## Overview
This deployment provides a complete AWS spot instance setup with:
- Amazon Q CLI with 17 MCP servers
- VS Code Server (web-based)
- Google Gemini Flash 2.5 integration
- Persistent storage across spot interruptions
- Simple shell commands for AI interaction

## Files Structure

### Core Deployment Files
- `user-data-script-s3copy.sh` - Main user data script (currently deployed)
- `enhanced-scripts/user-data-script-with-gemini-apikey.sh` - Latest enhanced script with API key
- `cloudformation/qclivscode-cfn_template.yaml` - CloudFormation template
- `deployment-scripts/cfn-deployment-script.sh` - Stack deployment script

### Test Scripts
- `test-scripts/test-gemini-cli.sh` - Comprehensive Gemini CLI testing

### Deployment Scripts
- `deployment-scripts/deploy-gemini-enhanced-script.sh` - S3 deployment script
- `deployment-scripts/install-gemini-current-instance.sh` - Manual installation script

## Simple Commands Available

### Gemini Commands
```bash
# General AI questions
gemini "What is Kubernetes?"

# Code generation
gcode "Python function to read CSV files"

# AI assistance
gai "best practices for AWS security"

# Interactive chat
gchat
```

## Configuration
- **API Key**: Pre-configured with your Google AI Studio key
- **Model**: gemini-2.0-flash-exp (Gemini Flash 2.5)
- **Persistent Storage**: All data survives spot interruptions
- **Region**: us-west-2
- **Instance Types**: M5, M6i, C5, C6i, R5, R6i (2xlarge)

## Access Information
- **SSH**: `ssh -i amazon-q-key-uswest2.pem ubuntu@<INSTANCE_IP>`
- **VS Code**: `http://<INSTANCE_IP>:8080`
- **Amazon Q CLI**: Available after `q login`

## Deployment Status
- **Current Stack**: amazon-q-cli-vscode-v10-enhanced-09jul2025
- **Status**: CREATE_COMPLETE
- **Instance**: 44.232.100.208 (m5.2xlarge)
- **Created**: 2025-07-09T11:37:00.466Z

## Features
✅ Amazon Q CLI with 17 MCP servers
✅ VS Code Server (passwordless access)
✅ Google Gemini Flash 2.5 integration
✅ 6 launch configurations for maximum availability
✅ Multi-AZ deployment across all us-west-2 zones
✅ Dynamic spot pricing with cost optimization
✅ Persistent storage across spot interruptions
✅ Development tools: Node.js, Python, Docker
✅ Simple shell commands for AI interaction

## Version History
- v10-enhanced-with-gemini-flash25-apikey-simplecommands (Latest)
- v10-enhanced-with-gemini-flash25-apikey
- v10-enhanced-with-gemini-basic
- v10-enhanced (Original)
