# V2 Deployment - Auto-Termination on Failure

## What's New in V2

### 1. **Automatic Instance Termination on Failure**
- If setup fails, instance terminates itself automatically
- **Prevents billing waste** for broken instances
- Spot fleet will launch a new instance automatically

### 2. **Enhanced Retry Logic**
- S3 script download: **5 retries** with exponential backoff (10s, 20s, 30s, 40s, 50s)
- Connection timeout: 30 seconds
- Max download time: 120 seconds
- Each retry waits longer (exponential backoff)

### 3. **Maximum Setup Time: 20 Minutes**
- If setup takes longer than 20 minutes, instance auto-terminates
- Prevents infinite hanging
- Sufficient time for complete setup (typical: 5-7 minutes)

### 4. **Enhanced Verification**
- Checks if VS Code Server service is active
- Verifies port 8080 is listening
- Only continues if both checks pass
- Otherwise: auto-terminates

## Files Created

### 1. Setup Script (S3)
**Location:** `s3://03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy-v2.sh`
**Local:** `/home/ajitn/qclispot-deployment/user-data-script-s3copy-v2.sh`

**Features:**
- Downloads main setup script with 5 retries
- 20-minute timeout protection
- Auto-termination on failure
- Enhanced logging

### 2. CloudFormation Template
**File:** `/home/ajitn/qclispot-deployment/mumbai-template-v2.yaml`

**Changes:**
- Uses v2 setup script URL
- Updated description
- Same infrastructure as v1

### 3. Deployment Script
**File:** `/home/ajitn/qclispot-deployment/deploy-mumbai-v2.sh`

**Usage:**
```bash
./deploy-mumbai-v2.sh
```

## How It Works

### Normal Flow (Success)
```
1. Instance launches
2. Downloads v2 wrapper script (with retries)
3. Wrapper downloads main setup script (with retries)
4. Main setup runs (installs VS Code, Amazon Q, etc.)
5. Verification: Service active? Port 8080 listening?
6. ✅ Success → Instance continues running
```

### Failure Flow (Auto-Termination)
```
1. Instance launches
2. Setup fails (network issue, timeout, etc.)
3. Script detects failure
4. Logs error details
5. ❌ Terminates instance automatically
6. Spot fleet launches new instance
7. New instance tries again
```

## Timeouts and Retries

| Component | Retries | Timeout | Backoff |
|-----------|---------|---------|---------|
| S3 Download | 5 | 120s | Exponential (10s-50s) |
| Main Setup | 1 | 20 min | N/A |
| Overall | Auto-retry via spot fleet | 20 min | New instance |

## Testing V2

### Test Normal Deployment
```bash
./deploy-mumbai-v2.sh
```

Wait 5-7 minutes, then check:
```bash
curl http://<ELASTIC_IP>:8080
```

### Test Failure Scenario
To test auto-termination, you can:
1. Deploy v2
2. SSH into instance during setup
3. Kill the setup process
4. Watch instance terminate automatically

## Cost Savings

**V1 (Old):**
- Setup fails → Instance keeps running
- Billing continues → Waste money
- Manual intervention needed

**V2 (New):**
- Setup fails → Instance terminates
- Billing stops immediately
- New instance launches automatically
- **Saves ~$0.30-0.50 per failure**

## Rollback to V1

If you need to use the old version:
```bash
./deploy-mumbai.sh  # Uses v1 (no auto-termination)
```

## Monitoring

Check setup status:
```bash
ssh -i amazon-q-key-mumbai.pem ubuntu@<IP> "tail -f /var/log/amazonq-vscode-enhanced-setup.log"
```

Check if instance will terminate:
```bash
ssh -i amazon-q-key-mumbai.pem ubuntu@<IP> "grep -i 'FATAL\|terminate' /var/log/amazonq-vscode-enhanced-setup.log"
```

## Recommendations

✅ **Use V2 for production** - Prevents billing waste
✅ **20-minute timeout is sufficient** - Typical setup: 5-7 minutes
✅ **5 retries handle transient failures** - Network glitches, S3 throttling
✅ **Spot fleet auto-recovery** - New instance launches if one fails

## Summary

**V2 adds intelligent failure handling:**
- Auto-terminates broken instances
- Retries transient failures
- Prevents billing waste
- No manual intervention needed

**Use V2 for all new deployments!**
