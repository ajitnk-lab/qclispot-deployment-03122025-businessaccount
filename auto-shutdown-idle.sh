#!/bin/bash
# Auto-shutdown script for idle VS Code instances
# Runs via cron every 5 minutes

LOG_FILE="/var/log/auto-shutdown.log"
STATE_FILE="/var/run/idle-check-count"
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
        echo "$(date): SHUTDOWN - Idle threshold reached, deleting CloudFormation stack" >> "$LOG_FILE"
        
        # Get instance metadata
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
        
        # Find CloudFormation stack name from instance tags
        STACK_NAME=$(aws ec2 describe-tags --region $REGION \
            --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:cloudformation:stack-name" \
            --query 'Tags[0].Value' --output text)
        
        if [ -n "$STACK_NAME" ] && [ "$STACK_NAME" != "None" ]; then
            echo "$(date): Deleting CloudFormation stack: $STACK_NAME" >> "$LOG_FILE"
            aws cloudformation delete-stack --region $REGION --stack-name "$STACK_NAME"
            echo "$(date): Stack deletion initiated successfully" >> "$LOG_FILE"
        else
            echo "$(date): No CloudFormation stack found, terminating instance only" >> "$LOG_FILE"
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
