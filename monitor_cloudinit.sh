#!/bin/bash

INSTANCE_ID="i-0e55b8a64ca9f011a"
REGION="us-west-2"
HOST="34.214.59.142"

echo "Monitoring cloud-init progress on instance $INSTANCE_ID"
echo "Press Ctrl+C to stop monitoring"
echo "----------------------------------------"

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Check instance status
    STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --region $REGION --query 'InstanceStatuses[0].InstanceStatus.Status' --output text 2>/dev/null)
    SYSTEM_STATUS=$(aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --region $REGION --query 'InstanceStatuses[0].SystemStatus.Status' --output text 2>/dev/null)
    
    echo "[$TIMESTAMP] Instance Status: $STATUS | System Status: $SYSTEM_STATUS"
    
    # Try to check if cloud-init is complete via HTTP (if web server is up)
    if curl -s --connect-timeout 3 http://$HOST:8080 >/dev/null 2>&1; then
        echo "[$TIMESTAMP] ✅ VS Code server is accessible - cloud-init likely complete!"
        break
    fi
    
    # Try to check SSH connectivity (indicates cloud-init user setup is done)
    if timeout 3 nc -z $HOST 22 2>/dev/null; then
        echo "[$TIMESTAMP] SSH port is open - instance is accessible"
    else
        echo "[$TIMESTAMP] SSH port not yet accessible"
    fi
    
    sleep 15
done
