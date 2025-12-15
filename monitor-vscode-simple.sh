#!/bin/bash

echo "=== VS Code Activity Monitor (Simplified) ==="
echo "Monitoring for 3 minutes (checking every 20 seconds)..."
echo ""

# Get VS Code process IDs
VSCODE_PIDS=$(pgrep -f "code-server" | tr '\n' ' ')

if [ -z "$VSCODE_PIDS" ]; then
    echo "No VS Code processes found"
    exit 1
fi

echo "Monitoring PIDs: $VSCODE_PIDS"
echo ""

# Monitor for 3 minutes (9 checks, 20 seconds apart)
for i in {1..9}; do
    timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] Check $i/9:"
    
    total_cpu=0
    
    for pid in $VSCODE_PIDS; do
        # Get CPU and memory
        stats=$(ps -p $pid -o %cpu,%mem,cmd --no-headers 2>/dev/null)
        if [ -n "$stats" ]; then
            cpu=$(echo "$stats" | awk '{print $1}')
            mem=$(echo "$stats" | awk '{print $2}')
            echo "  PID $pid: CPU=${cpu}%, MEM=${mem}%"
            
            # Add to total (handle decimal)
            total_cpu=$(awk "BEGIN {print $total_cpu + $cpu}")
        fi
    done
    
    echo "  → Total CPU: ${total_cpu}%"
    
    # Determine activity
    is_active=$(awk "BEGIN {print ($total_cpu > 0.5) ? 1 : 0}")
    if [ "$is_active" = "1" ]; then
        echo "  → Status: ACTIVE"
    else
        echo "  → Status: IDLE"
    fi
    
    echo ""
    
    if [ $i -lt 9 ]; then
        sleep 20
    fi
done

echo "=== Implementation Logic ==="
echo "The auto-shutdown script will:"
echo "1. Check CPU every 5 minutes"
echo "2. If CPU < 0.5% for 12 consecutive checks (60 minutes)"
echo "3. Then shutdown the instance"
echo ""
echo "Now: Try editing a file in VS Code and run this again to see CPU spike!"
