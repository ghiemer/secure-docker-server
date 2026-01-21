#!/bin/bash
# /usr/local/bin/security-watchdog
set -u

# --- CONFIGURATION ---
# Space separated list of allowed TCP ports
# 22 (SSH), 80 (HTTP), 443 (HTTPS)
ALLOWED_PORTS="22 80 443"
HOSTNAME=$(hostname)

# --- LOGIC ---

# Get all listening TCP ports on external interfaces (0.0.0.0 or ::)
# We exclude 127.0.0.1 (Localhost services like DBs are fine)
OPEN_PORTS=$(ss -tuln | awk 'NR>1 {print $5}' | grep -vE '127\.0\.0\.1|\[::1\]' | awk -F: '{print $(NF)}' | sort -u)

VIOLATION_DETECTED=0

for port in $OPEN_PORTS; do
    # Check if the found port is in the allowed list
    if [[ ! " $ALLOWED_PORTS " =~ " $port " ]]; then
        MSG="🚨 SECURITY ALERT on $HOSTNAME: Unauthorized public port detected: $port"
        
        # 1. Log to Syslog (auth.log/syslog) so Fail2Ban or monitoring agents see it
        logger -p auth.crit -t "SECURITY_WATCHDOG" "$MSG"
        
        # 2. Output to stdout for systemd logs
        echo "$MSG"
        
        VIOLATION_DETECTED=1
    fi
done

if [ $VIOLATION_DETECTED -eq 0 ]; then
    echo "✅ System Secure. Only allowed ports ($ALLOWED_PORTS) are open."
    exit 0
else
    # Exit with error code to mark unit as failed in systemd
    exit 1
fi
