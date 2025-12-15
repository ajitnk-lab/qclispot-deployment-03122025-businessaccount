#!/bin/bash

echo "=== VS Code Activity Monitor ==="
echo "Monitoring for 5 minutes (checking every 30 seconds)..."
echo ""

# Get VS Code process IDs
VSCODE_PIDS=$(pgrep -f "code-server")

if [ -z "$VSCODE_PIDS" ]; then
    echo "No VS Code processes found"
    exit 1
fi

echo "Monitoring PIDs: $VSCODE_PIDS"
echo ""

# Function to get process stats
get_stats() {
    local pid=$1
    
    # CPU usage
    cpu=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | xargs)
    
    # I/O stats from /proc
    if [ -f /proc/$pid/io ]; then
        read_bytes=$(sudo grep "read_bytes:" /proc/$pid/io 2>/dev/null | awk '{print $2}')
        write_bytes=$(sudo grep "write_bytes:" /proc/$pid/io 2>/dev/null | awk '{print $2}')
        read_bytes=${read_bytes:-0}
        write_bytes=${write_bytes:-0}
    else
        read_bytes=0
        write_bytes=0
    fi
    
    echo "$cpu|$read_bytes|$write_bytes"
}

# Monitor for 5 minutes (10 checks, 30 seconds apart)
for i in {1..10}; do
    timestamp=$(date '+%H:%M:%S')
    echo "[$timestamp] Check $i/10:"
    
    total_cpu=0
    total_read=0
    total_write=0
    
    for pid in $VSCODE_PIDS; do
        stats=$(get_stats $pid)
        cpu=$(echo $stats | cut -d'|' -f1)
        read_bytes=$(echo $stats | cut -d'|' -f2)
        write_bytes=$(echo $stats | cut -d'|' -f3)
        
        echo "  PID $pid: CPU=${cpu}%, Read=${read_bytes} bytes, Write=${write_bytes} bytes"
        
        # Store for comparison
        eval "prev_read_$pid=\${curr_read_$pid:-$read_bytes}"
        eval "prev_write_$pid=\${curr_write_$pid:-$write_bytes}"
        eval "curr_read_$pid=$read_bytes"
        eval "curr_write_$pid=$write_bytes"
        
        # Calculate delta
        if [ $i -gt 1 ]; then
            eval "prev_r=\${prev_read_$pid:-0}"
            eval "prev_w=\${prev_write_$pid:-0}"
            read_delta=$((read_bytes - prev_r))
            write_delta=$((write_bytes - prev_w))
            echo "    → Delta: Read=+${read_delta} bytes, Write=+${write_delta} bytes"
        fi
        
        total_cpu=$(echo "$total_cpu + $cpu" | bc 2>/dev/null || echo "0")
    done
    
    echo "  Total CPU: ${total_cpu}%"
    echo ""
    
    if [ $i -lt 10 ]; then
        sleep 30
    fi
done

echo "=== Summary ==="
echo "If all checks showed:"
echo "  - CPU near 0%"
echo "  - Read/Write deltas near 0"
echo "  → System is IDLE (would shutdown after threshold)"
echo ""
echo "If any checks showed:"
echo "  - CPU spikes"
echo "  - Read/Write activity"
echo "  → System is ACTIVE (keep running)"
