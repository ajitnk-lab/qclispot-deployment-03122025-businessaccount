#!/bin/bash

INSTANCE_IP="100.20.106.120"
SSH_KEY="./amazon-q-key-uswest2.pem"
USER="ubuntu"
PORT="8080"

echo "Starting VS Code server setup monitoring for $INSTANCE_IP"
echo "Time: $(date)"
echo "----------------------------------------"

while true; do
    echo "[$(date '+%H:%M:%S')] Checking setup status..."
    
    # Check cloud-init status
    CLOUD_INIT_STATUS=$(ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$USER@$INSTANCE_IP" "cloud-init status" 2>/dev/null)
    echo "Cloud-init: $CLOUD_INIT_STATUS"
    
    # Check setup logs (last 3 lines)
    SETUP_LOG=$(ssh -i "$SSH_KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$USER@$INSTANCE_IP" "tail -3 /var/log/cloud-init-output.log 2>/dev/null || echo 'Log not available'")
    echo "Setup log: $SETUP_LOG"
    
    # Test web accessibility
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://$INSTANCE_IP:$PORT" 2>/dev/null || echo "000")
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "302" ] || [ "$HTTP_STATUS" = "301" ]; then
        echo "✅ VS Code server is accessible! HTTP Status: $HTTP_STATUS"
        echo "🎉 Setup completed successfully at $(date)"
        echo "Access your VS Code server at: http://$INSTANCE_IP:$PORT"
        break
    else
        echo "❌ VS Code server not yet accessible (HTTP: $HTTP_STATUS)"
    fi
    
    echo "----------------------------------------"
    sleep 30
done
