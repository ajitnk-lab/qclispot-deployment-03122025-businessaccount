#!/bin/bash
STACK_NAME="amazon-q-cli-mumbai-v2-16dec2025"
REGION="ap-south-1"
IP="13.204.197.77"
LOG="/home/ajitn/qclispot-deployment/monitor.log"

log() { echo "[$(date '+%H:%M:%S')] $1" | tee -a "$LOG"; }

log "=== Monitoring started ==="
START_TIME=$(date +%s)

for i in {1..15}; do
    ELAPSED=$(( ($(date +%s) - START_TIME) / 60 ))
    log "Check $i/15 (${ELAPSED}min elapsed)"
    
    # Check if stack still exists
    if ! aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &>/dev/null; then
        log "✅ Stack deleted successfully!"
        exit 0
    fi
    
    # Check idle count on instance
    COUNT=$(ssh -i amazon-q-key-mumbai.pem -o StrictHostKeyChecking=no ubuntu@$IP "sudo cat /var/run/idle-check-count 2>/dev/null" 2>/dev/null || echo "0")
    log "Idle count: $COUNT/12"
    
    # After 65 minutes, force delete if still running
    if [ $ELAPSED -ge 65 ]; then
        log "⚠️ 65 min passed, forcing stack deletion"
        aws cloudformation delete-stack --stack-name "$STACK_NAME" --region "$REGION"
        log "✅ Force deletion initiated"
        exit 0
    fi
    
    sleep 300  # 5 minutes
done

log "⚠️ Monitoring ended after 75 minutes"
