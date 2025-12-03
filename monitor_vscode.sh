#!/bin/bash

INSTANCE_ID="i-06d2cf4d095418113"
PUBLIC_IP="44.237.151.135"
REGION="us-west-2"
VSCODE_PORT="8080"

echo "=== VS Code Server Monitor Started at $(date) ==="
echo "Instance: $INSTANCE_ID"
echo "Public IP: $PUBLIC_IP"
echo "Monitoring VS Code on port $VSCODE_PORT"
echo "=========================================="

check_vscode_accessibility() {
    echo "[$(date '+%H:%M:%S')] Checking VS Code accessibility..."
    
    # Check if port is open
    if timeout 5 nc -z $PUBLIC_IP $VSCODE_PORT 2>/dev/null; then
        echo "✅ Port $VSCODE_PORT is accessible"
        
        # Check HTTP response
        HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://$PUBLIC_IP:$VSCODE_PORT/ 2>/dev/null)
        if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ]; then
            echo "✅ VS Code server responding (HTTP $HTTP_STATUS)"
        else
            echo "⚠️  VS Code server not responding properly (HTTP $HTTP_STATUS)"
        fi
    else
        echo "❌ Port $VSCODE_PORT not accessible"
    fi
}

check_instance_status() {
    echo "[$(date '+%H:%M:%S')] Checking instance status..."
    STATUS=$(aws ec2 describe-instances --region $REGION --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null)
    echo "Instance state: $STATUS"
}

get_cloud_init_logs() {
    echo "[$(date '+%H:%M:%S')] Fetching cloud-init logs..."
    aws ssm send-command \
        --region $REGION \
        --instance-ids $INSTANCE_ID \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["tail -20 /var/log/cloud-init-output.log"]' \
        --query 'Command.CommandId' \
        --output text > /tmp/command_id.txt 2>/dev/null
    
    if [ -f /tmp/command_id.txt ]; then
        COMMAND_ID=$(cat /tmp/command_id.txt)
        sleep 3
        aws ssm get-command-invocation \
            --region $REGION \
            --command-id $COMMAND_ID \
            --instance-id $INSTANCE_ID \
            --query 'StandardOutputContent' \
            --output text 2>/dev/null | head -20
    else
        echo "Unable to fetch cloud-init logs via SSM"
    fi
}

# Main monitoring loop
while true; do
    echo ""
    echo "=== Status Check at $(date) ==="
    
    check_instance_status
    check_vscode_accessibility
    
    echo ""
    echo "=== Cloud-Init Logs ==="
    get_cloud_init_logs
    
    echo ""
    echo "Next check in 30 seconds... (Ctrl+C to stop)"
    sleep 30
done
