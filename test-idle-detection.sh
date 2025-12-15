#!/bin/bash

echo "=== Idle Detection Test ==="
echo "Testing if system would shutdown based on activity..."
echo ""

# Configuration
IDLE_THRESHOLD_MINUTES=60
CPU_THRESHOLD=5

# 1. Check SSH sessions and idle time
echo "1. SSH Session Analysis:"
w -h | while read line; do
    user=$(echo $line | awk '{print $1}')
    tty=$(echo $line | awk '{print $2}')
    idle=$(echo $line | awk '{print $4}')
    what=$(echo $line | awk '{print $8}')
    echo "   User: $user, TTY: $tty, Idle: $idle, Process: $what"
done
echo ""

# 2. Get minimum idle time in minutes
echo "2. Minimum Idle Time:"
min_idle=$(w -h | awk '{print $4}' | sed 's/s$//' | sort -n | head -1)
if [[ $min_idle == *m* ]]; then
    min_idle_minutes=$(echo $min_idle | sed 's/m//')
elif [[ $min_idle == *:* ]]; then
    hours=$(echo $min_idle | cut -d: -f1)
    mins=$(echo $min_idle | cut -d: -f2)
    min_idle_minutes=$((hours * 60 + mins))
elif [[ $min_idle == *s* ]] || [[ $min_idle =~ ^[0-9]+$ ]]; then
    min_idle_minutes=0
else
    min_idle_minutes=0
fi
echo "   Minimum idle time: ${min_idle_minutes} minutes (threshold: ${IDLE_THRESHOLD_MINUTES} min)"
echo ""

# 3. Check CPU usage (1 minute average)
echo "3. CPU Usage Analysis:"
cpu_idle=$(top -bn2 -d 1 | grep "Cpu(s)" | tail -1 | awk '{print $8}' | cut -d'%' -f1)
cpu_used=$(echo "100 - $cpu_idle" | bc)
echo "   CPU Usage: ${cpu_used}% (threshold: ${CPU_THRESHOLD}%)"
echo ""

# 4. Check VS Code processes
echo "4. VS Code Server Processes:"
vscode_procs=$(ps aux | grep -E "vscode-server|code-server" | grep -v grep)
if [ -z "$vscode_procs" ]; then
    echo "   No VS Code server processes found"
else
    echo "$vscode_procs" | while read line; do
        cpu=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $4}')
        cmd=$(echo $line | awk '{print $11}')
        echo "   Process: $cmd (CPU: ${cpu}%, MEM: ${mem}%)"
    done
fi
echo ""

# 5. Network activity on SSH port
echo "5. SSH Connection Activity:"
ssh_connections=$(ss -tn state established '( dport = :22 or sport = :22 )' | tail -n +2)
if [ -z "$ssh_connections" ]; then
    echo "   No active SSH connections"
else
    echo "   Active SSH connections found:"
    echo "$ssh_connections" | head -3
fi
echo ""

# 6. Decision logic
echo "=== SHUTDOWN DECISION ==="
should_shutdown=false

if (( $(echo "$min_idle_minutes >= $IDLE_THRESHOLD_MINUTES" | bc -l) )); then
    echo "✓ Idle time exceeds threshold (${min_idle_minutes} >= ${IDLE_THRESHOLD_MINUTES} min)"
    if (( $(echo "$cpu_used < $CPU_THRESHOLD" | bc -l) )); then
        echo "✓ CPU usage below threshold (${cpu_used}% < ${CPU_THRESHOLD}%)"
        should_shutdown=true
    else
        echo "✗ CPU usage above threshold (${cpu_used}% >= ${CPU_THRESHOLD}%)"
    fi
else
    echo "✗ System not idle long enough (${min_idle_minutes} < ${IDLE_THRESHOLD_MINUTES} min)"
fi

echo ""
if [ "$should_shutdown" = true ]; then
    echo "🔴 DECISION: System WOULD shutdown (idle + low CPU)"
    echo "   (This is a test - not actually shutting down)"
else
    echo "🟢 DECISION: System stays running (active or high CPU)"
fi
echo ""
echo "=== Test Complete ==="
