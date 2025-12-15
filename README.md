# Amazon Q CLI Spot Fleet Deployment

Complete deployment solution for Amazon Q CLI with VS Code Server on AWS Spot Instances with auto-shutdown for idle instances.

## 📁 Repository Structure

### Deployment Scripts
- **`deploy-mumbai-v2.sh`** - Main deployment script for Mumbai region (ap-south-1)
- **`deploy-uswest2a-only.sh`** - Deployment script for US West 2 region

### CloudFormation Templates
- **`mumbai-template-v2.yaml`** - CloudFormation template for Mumbai deployment
  - Spot Fleet with 6 instance types (M6a, M6i, C5, C6i, R5, R6i)
  - Single AZ deployment (ap-south-1a)
  - Elastic IP, VPC, Security Groups
  - IAM roles with AdministratorAccess

- **`uswest2a-only-template.yaml`** - CloudFormation template for US West 2

### User Data Scripts
- **`user-data-script-s3copy-v2.sh`** - Main setup script with auto-shutdown feature
  - Downloads from S3 and executes setup
  - Installs auto-shutdown monitoring
  - Configures VS Code Server
  - Sets up cron job for idle detection

- **`auto-shutdown-idle.sh`** - Standalone auto-shutdown script
  - Monitors VS Code CPU usage every 5 minutes
  - Deletes CloudFormation stack after 60 minutes of inactivity
  - Logs activity to `/var/log/auto-shutdown.log`

### Configuration Files
- **`amazon-q-key-mumbai.pem`** - SSH key for Mumbai region
- **`amazon-q-key-uswest2.pem`** - SSH key for US West 2 region

## 🚀 Quick Start

### Deploy to Mumbai (ap-south-1)
```bash
chmod +x deploy-mumbai-v2.sh
./deploy-mumbai-v2.sh
```

### Deploy to US West 2
```bash
chmod +x deploy-uswest2a-only.sh
./deploy-uswest2a-only.sh
```

## 📦 S3 Bucket Configuration

**Bucket Name:** `03-july-2025-qclvscodespot-4.14pm`  
**Region:** `us-west-2`  
**Public Access:** Enabled for user-data scripts

### S3 Files
- `s3://03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh` - Main setup script
- `s3://03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy.sh` - Base setup script

**Public URL:**
```
https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh
```

## ⚡ Auto-Shutdown Feature

### How It Works
1. **Monitoring**: Checks VS Code process CPU usage every 5 minutes
2. **Idle Detection**: If CPU < 0.5% for 12 consecutive checks (60 minutes)
3. **Action**: Deletes the entire CloudFormation stack (prevents Spot Fleet from launching new instances)
4. **Reset**: Any activity (CPU > 0.5%) resets the idle counter to 0

### Configuration
- **Idle Threshold**: 60 minutes (12 checks × 5 minutes)
- **CPU Threshold**: 5.0%
- **Check Interval**: Every 5 minutes (cron job)
- **Log File**: `/var/log/auto-shutdown.log`
- **State File**: `/var/run/idle-check-count`

### Customization
Edit `/usr/local/bin/auto-shutdown-idle.sh` on the instance:
```bash
IDLE_THRESHOLD=12  # Change to 6 for 30 min, 24 for 2 hours
CPU_THRESHOLD=5.0  # Adjust CPU sensitivity (5% works well for VS Code)
```

## 🔧 Instance Configuration

### Supported Instance Types
- **M6a.2xlarge** - AMD General Purpose (Primary)
- **M6i.2xlarge** - Intel General Purpose
- **C5.2xlarge** - Compute Optimized
- **C6i.2xlarge** - Latest Compute Optimized
- **R5.2xlarge** - Memory Optimized
- **R6i.2xlarge** - Latest Memory Optimized

### Resources Created
- VPC (10.0.0.0/16)
- Public Subnet (10.0.1.0/24)
- Internet Gateway
- Security Group (SSH:22, VS Code:8080, HTTP:80, HTTPS:443)
- Elastic IP
- Spot Fleet Request
- IAM Role with AdministratorAccess
- EBS Volume (30GB persistent storage)

## 🌐 Access Information

### VS Code Server
```
http://<ELASTIC_IP>:8080
```

### SSH Access
```bash
ssh -i amazon-q-key-mumbai.pem ubuntu@<ELASTIC_IP>
```

### Check Auto-Shutdown Status
```bash
ssh -i amazon-q-key-mumbai.pem ubuntu@<ELASTIC_IP> "tail -20 /var/log/auto-shutdown.log"
```

## 📊 Monitoring

### View Auto-Shutdown Logs
```bash
tail -f /var/log/auto-shutdown.log
```

### Check Idle Counter
```bash
cat /var/run/idle-check-count
```

### View Cron Jobs
```bash
crontab -l
```

### Manual Test
```bash
/usr/local/bin/auto-shutdown-idle.sh
```

## 🛠️ Troubleshooting

### Disable Auto-Shutdown Temporarily
```bash
# Remove cron job
crontab -l | grep -v auto-shutdown-idle.sh | crontab -

# Re-enable later
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/auto-shutdown-idle.sh") | crontab -
```

### Check VS Code Processes
```bash
ps aux | grep code-server
```

### View Setup Logs
```bash
tail -f /var/log/amazonq-vscode-enhanced-setup.log
```

## 📝 Deployment Parameters

### CloudFormation Parameters
- **KeyName**: `amazon-q-key-uswest2` (default)
- **SpotPriceM6a**: `0.320` USD/hour
- **SpotPriceM6i**: `0.350` USD/hour
- **SpotPriceC5**: `0.300` USD/hour
- **SpotPriceC6i**: `0.280` USD/hour
- **SpotPriceR5**: `0.450` USD/hour
- **SpotPriceR6i**: `0.400` USD/hour

## 🔄 Update Deployment

### Update S3 Script
```bash
aws s3 cp user-data-script-s3copy-v2.sh \
  s3://03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh \
  --region us-west-2
```

### Redeploy Stack
```bash
# Delete existing stack
aws cloudformation delete-stack --stack-name <STACK_NAME> --region ap-south-1

# Deploy new stack
./deploy-mumbai-v2.sh
```

## 📌 Important Notes

1. **Auto-Shutdown**: Enabled by default on all new deployments
2. **Stack Deletion**: Auto-shutdown deletes the entire CloudFormation stack, not just the instance
3. **Persistent Storage**: 30GB EBS volume persists across instance replacements
4. **Elastic IP**: Remains constant even if instance is replaced
5. **Cost Optimization**: Auto-shutdown prevents billing for idle instances

## 🔐 Security

- All EBS volumes are encrypted
- Security group restricts access to necessary ports only
- IAM role has AdministratorAccess (adjust as needed)
- SSH keys required for access

## 📞 Support

For issues or questions, check:
- Setup logs: `/var/log/amazonq-vscode-enhanced-setup.log`
- Auto-shutdown logs: `/var/log/auto-shutdown.log`
- CloudFormation events in AWS Console

## 📅 Version History

- **V11.0** - Added auto-shutdown feature with CloudFormation stack deletion
- **V10.0** - Enhanced setup with 17 MCP servers
- **V9.0** - Multi-instance type support with Spot Fleet
