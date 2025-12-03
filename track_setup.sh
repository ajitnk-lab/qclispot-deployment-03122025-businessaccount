#!/bin/bash

INSTANCE_ID="i-06d2cf4d095418113"
PUBLIC_IP="44.237.151.135"
REGION="us-west-2"

echo "=== VS Code Setup Progress Monitor ==="
echo "Instance: $INSTANCE_ID ($PUBLIC_IP)"
echo "Started at: $(date)"
echo "======================================"

while true; do
    echo ""
    echo "[$(date '+%H:%M:%S')] Checking setup progress..."
    
    # Check if cloud-init is still running
    CLOUD_INIT_STATUS=$(aws ssm send-command \
        --region $REGION \
        --instance-ids $INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cloud-init status --wait || echo TIMEOUT"]' \
        --query 'Command.CommandId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$CLOUD_INIT_STATUS" ]; then
        sleep 3
        aws ssm get-command-invocation \
            --region $REGION \
            --command-id $CLOUD_INIT_STATUS \
            --instance-id $INSTANCE_ID \
            --query 'StandardOutputContent' \
            --output text 2>/dev/null
    fi
    
    # Check VS Code accessibility
    echo -n "VS Code port 8080: "
    timeout 3 nc -z $PUBLIC_IP 8080 && echo "✅ ACCESSIBLE" || echo "❌ Not accessible"
    
    # Get latest setup logs
    echo "Latest setup activity:"
    LOGS_CMD=$(aws ssm send-command \
        --region $REGION \
        --instance-ids $INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["tail -5 /var/log/amazonq-vscode-enhanced-setup.log 2>/dev/null || tail -5 /var/log/cloud-init-output.log"]' \
        --query 'Command.CommandId' \
        --output text 2>/dev/null)
    
    if [ ! -z "$LOGS_CMD" ]; then
        sleep 2
        aws ssm get-command-invocation \
            --region $REGION \
            --command-id $LOGS_CMD \
            --instance-id $INSTANCE_ID \
            --query 'StandardOutputContent' \
            --output text 2>/dev/null | sed 's/^/  /'
    fi
    
    echo "Next check in 15 seconds... (Ctrl+C to stop)"
    sleep 15
done
