#!/bin/bash -xe

# Enhanced Amazon Q CLI + VS Code Server Setup Script - V11 with Auto-Termination
# Adds: Retries, timeouts, and automatic instance termination on failure
# Version: 11.0 - Production Ready with failure handling

# CRITICAL: Set max setup time (20 minutes)
MAX_SETUP_TIME=1200
SETUP_START=$(date +%s)

# Enhanced logging function with timestamps and levels
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a /var/log/amazonq-vscode-enhanced-setup.log >&2
}

# Fatal error handler - terminates instance
fatal_error() {
    local error_msg="$1"
    log "FATAL" "$error_msg"
    log "FATAL" "Setup failed. Terminating instance to prevent billing waste..."
    
    # Get instance ID
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
    
    # Terminate self
    aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $REGION || true
    
    exit 1
}

# Check if setup time exceeded
check_timeout() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - SETUP_START))
    
    if [ $elapsed -gt $MAX_SETUP_TIME ]; then
        fatal_error "Setup timeout exceeded ($elapsed seconds > $MAX_SETUP_TIME seconds)"
    fi
}

# Error handler function with detailed logging
error_handler() {
    local exit_code=$?
    local line_number=$1
    log "ERROR" "Script failed at line $line_number with exit code $exit_code"
    log "ERROR" "Last command: ${BASH_COMMAND}"
    # Don't exit immediately, let retry logic handle it
}

# Set up error handling (non-fatal for better resilience)
trap 'error_handler $LINENO' ERR
set +e  # Don't exit on errors, handle them gracefully

# Initialize logging
log "INFO" "🚀 Starting Enhanced Amazon Q CLI + VS Code Server Setup V11.0"
log "INFO" "📋 PHASE 1: Enhanced System Preparation and Instance Analysis"

# CRITICAL FIX: Set HOME environment variable for all operations
export HOME=/root
log "INFO" "🔧 HOME environment variable set to: $HOME"

# Get instance metadata with enhanced information
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
INSTANCE_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
INSTANCE_TYPE=$(curl -s http://169.254.169.254/latest/meta-data/instance-type)

# Extract instance family from instance type
INSTANCE_FAMILY=$(echo "$INSTANCE_TYPE" | cut -d'.' -f1)

log "INFO" "Instance ID: $INSTANCE_ID"
log "INFO" "Region: $REGION" 
log "INFO" "Availability Zone: $INSTANCE_AZ"
log "INFO" "Public IP: $PUBLIC_IP"
log "INFO" "Instance Type: $INSTANCE_TYPE"
log "INFO" "Instance Family: $INSTANCE_FAMILY"
log "INFO" "Max Setup Time: $MAX_SETUP_TIME seconds (20 minutes)"

# Instance family specific configurations
case $INSTANCE_FAMILY in
    "m5"|"m6i"|"m6a")
        INSTANCE_CATEGORY="General Purpose"
        MEMORY_CONFIG="balanced"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="6g"
        NODE_MAX_OLD_SPACE="4096"
        ;;
    "c5"|"c6i")
        INSTANCE_CATEGORY="Compute Optimized"
        MEMORY_CONFIG="standard"
        CPU_CONFIG="high"
        DOCKER_MEMORY_LIMIT="4g"
        NODE_MAX_OLD_SPACE="3072"
        ;;
    "r5"|"r6i")
        INSTANCE_CATEGORY="Memory Optimized"
        MEMORY_CONFIG="high"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="12g"
        NODE_MAX_OLD_SPACE="8192"
        ;;
    *)
        INSTANCE_CATEGORY="Unknown"
        MEMORY_CONFIG="balanced"
        CPU_CONFIG="balanced"
        DOCKER_MEMORY_LIMIT="6g"
        NODE_MAX_OLD_SPACE="4096"
        log "WARN" "Unknown instance family: $INSTANCE_FAMILY, using default configuration"
        ;;
esac

log "INFO" "Instance Category: $INSTANCE_CATEGORY"
log "INFO" "Memory Configuration: $MEMORY_CONFIG"
log "INFO" "CPU Configuration: $CPU_CONFIG"

# Enhanced retry function with exponential backoff
retry_command() {
    local max_attempts="$1"
    local delay="$2"
    local description="$3"
    shift 3
    local command=("$@")
    
    for attempt in $(seq 1 $max_attempts); do
        check_timeout  # Check if we've exceeded max setup time
        
        log "INFO" "Attempting $description (attempt $attempt/$max_attempts)"
        if "${command[@]}"; then
            log "SUCCESS" "$description completed successfully"
            return 0
        else
            local exit_code=$?
            if [ $attempt -eq $max_attempts ]; then
                log "ERROR" "$description failed after $max_attempts attempts (exit code: $exit_code)"
                return 1
            fi
            # Exponential backoff
            local wait_time=$((delay * attempt))
            log "WARN" "$description failed (exit code: $exit_code), retrying in ${wait_time}s..."
            sleep $wait_time
        fi
    done
}

# Download main setup script from S3 with retries
log "INFO" "📥 Downloading main setup script from S3..."
if ! retry_command 5 10 "S3 script download" curl -fsSL -o /tmp/main-setup.sh --connect-timeout 30 --max-time 120 "https://s3.us-west-2.amazonaws.com/03-july-2025-qclvscodespot-4.14pm/user-data-script-s3copy.sh"; then
    fatal_error "Failed to download setup script from S3 after 5 attempts"
fi

chmod +x /tmp/main-setup.sh

# Execute main setup script
log "INFO" "🚀 Executing main setup script..."
if ! /tmp/main-setup.sh 2>&1 | tee -a /var/log/amazonq-vscode-enhanced-setup.log; then
    fatal_error "Main setup script execution failed"
fi

# Verify VS Code Server is running
log "INFO" "🔍 Verifying VS Code Server installation..."
sleep 10

if ! systemctl is-active --quiet code-server@ubuntu; then
    log "ERROR" "VS Code Server service is not active"
    fatal_error "VS Code Server failed to start"
fi

if ! ss -tlnp | grep -q ":8080"; then
    log "ERROR" "Port 8080 is not listening"
    fatal_error "VS Code Server port 8080 not accessible"
fi

# Final verification
log "SUCCESS" "✅ Setup completed successfully!"
log "SUCCESS" "✅ VS Code Server is running on port 8080"
log "SUCCESS" "✅ Instance will continue running"

# Mark setup as successful
echo "SETUP_SUCCESS_V11" > /tmp/setup-status.txt
date > /tmp/setup-complete-time.txt

# Install auto-shutdown script for idle detection
log "INFO" "📥 Installing auto-shutdown script for idle detection..."

# Save stack name for auto-shutdown script
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
FLEET_ID=$(aws ec2 describe-tags --region $REGION \
    --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:ec2spot:fleet-request-id" \
    --query 'Tags[0].Value' --output text 2>/dev/null)

if [ -n "$FLEET_ID" ] && [ "$FLEET_ID" != "None" ]; then
    log "INFO" "🔍 Finding CloudFormation stack for Fleet ID: $FLEET_ID"
    for stack in $(aws cloudformation list-stacks --region $REGION --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE --query 'StackSummaries[*].StackName' --output text); do
        FOUND=$(aws cloudformation list-stack-resources --region $REGION --stack-name $stack --query "StackResourceSummaries[?PhysicalResourceId=='$FLEET_ID'].PhysicalResourceId" --output text 2>/dev/null)
        if [ -n "$FOUND" ]; then
            echo "$stack" | sudo tee /var/run/cfn-stack-name > /dev/null
            log "INFO" "💾 Saved stack name: $stack"
            break
        fi
    done
else
    log "WARN" "Fleet ID not found, stack name will not be saved"
fi

cat > /usr/local/bin/auto-shutdown-idle.sh << 'AUTOSHUTDOWN_EOF'
#!/bin/bash
# Auto-shutdown script for idle VS Code instances
# Runs via cron every 5 minutes

LOG_FILE="/var/log/auto-shutdown.log"
STATE_FILE="/var/run/idle-check-count"
STACK_NAME_FILE="/var/run/cfn-stack-name"
IDLE_THRESHOLD=12  # 12 checks * 5 min = 60 minutes
CPU_THRESHOLD=5.0  # 5% CPU threshold

# Initialize state file if doesn't exist
[ ! -f "$STATE_FILE" ] && echo "0" > "$STATE_FILE"

# Get current idle count
IDLE_COUNT=$(cat "$STATE_FILE")

# Get VS Code process CPU usage
VSCODE_PIDS=$(pgrep -f "code-server")

if [ -z "$VSCODE_PIDS" ]; then
    echo "$(date): No VS Code processes found, resetting counter" >> "$LOG_FILE"
    echo "0" > "$STATE_FILE"
    exit 0
fi

# Calculate total CPU
TOTAL_CPU=0
for pid in $VSCODE_PIDS; do
    CPU=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | xargs)
    [ -n "$CPU" ] && TOTAL_CPU=$(awk "BEGIN {print $TOTAL_CPU + $CPU}")
done

# Check if idle
IS_IDLE=$(awk "BEGIN {print ($TOTAL_CPU < $CPU_THRESHOLD) ? 1 : 0}")

if [ "$IS_IDLE" = "1" ]; then
    IDLE_COUNT=$((IDLE_COUNT + 1))
    echo "$(date): IDLE - CPU: ${TOTAL_CPU}%, Count: ${IDLE_COUNT}/${IDLE_THRESHOLD}" >> "$LOG_FILE"
    
    if [ $IDLE_COUNT -ge $IDLE_THRESHOLD ]; then
        echo "$(date): SHUTDOWN - Idle threshold reached" >> "$LOG_FILE"
        
        # Get instance metadata
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        
        # Try to get stack name from saved file first
        if [ -f "$STACK_NAME_FILE" ]; then
            STACK_NAME=$(cat "$STACK_NAME_FILE")
            echo "$(date): Found stack name from file: $STACK_NAME" >> "$LOG_FILE"
        fi
        
        # Verify stack exists and delete it
        if [ -n "$STACK_NAME" ] && [ "$STACK_NAME" != "None" ]; then
            if aws cloudformation describe-stacks --region $REGION --stack-name "$STACK_NAME" >/dev/null 2>&1; then
                echo "$(date): Deleting CloudFormation stack: $STACK_NAME" >> "$LOG_FILE"
                aws cloudformation delete-stack --region $REGION --stack-name "$STACK_NAME"
                echo "$(date): Stack deletion command executed successfully" >> "$LOG_FILE"
            else
                echo "$(date): Stack $STACK_NAME not found, terminating instance" >> "$LOG_FILE"
                aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID
            fi
        else
            echo "$(date): No stack name found, terminating instance only" >> "$LOG_FILE"
            aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_ID
        fi
        
        echo "0" > "$STATE_FILE"
    else
        echo "$IDLE_COUNT" > "$STATE_FILE"
    fi
else
    echo "$(date): ACTIVE - CPU: ${TOTAL_CPU}%, Resetting counter" >> "$LOG_FILE"
    echo "0" > "$STATE_FILE"
fi
AUTOSHUTDOWN_EOF

chmod +x /usr/local/bin/auto-shutdown-idle.sh

# Add cron job to run every 5 minutes
log "INFO" "⏰ Setting up cron job for auto-shutdown..."
sudo -u ubuntu bash -c '(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/auto-shutdown-idle.sh") | crontab -'

log "SUCCESS" "✅ Auto-shutdown script installed (60 min idle threshold)"
log "INFO" "💡 Auto-shutdown will DELETE the CloudFormation stack after 60 min of inactivity"

exit 0
