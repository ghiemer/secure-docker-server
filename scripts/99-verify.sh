#!/bin/bash
set -e
set -x  # Enable full command tracing for logging

# Farben
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${BLUE}🕵️  STARTING FINAL SYSTEM AUDIT...${NC}"
echo "---------------------------------------------------"

ERRORS=0

# 1. Check User
TARGET_USER=$(cat /root/.server_setup_user 2>/dev/null || echo "unknown")
if id "$TARGET_USER" &>/dev/null; then
    echo -e "✅ User '$TARGET_USER': \t\t${GREEN}EXISTS${NC}"
else
    echo -e "❌ User '$TARGET_USER': \t\t${RED}MISSING${NC}"
    ERRORS=$((ERRORS+1))
fi

# 2. Check SSH Port & Config
TARGET_PORT=$(cat /root/.server_setup_port 2>/dev/null || echo "22")
CURRENT_SSH_PORT=$(grep "^Port " /etc/ssh/sshd_config | awk '{print $2}')
if [ "$TARGET_PORT" == "$CURRENT_SSH_PORT" ]; then
    echo -e "✅ SSH Config Port: \t\t${GREEN}$TARGET_PORT${NC}"
else
    echo -e "❌ SSH Config Port: \t\t${RED}MISMATCH (Config: $CURRENT_SSH_PORT, Expected: $TARGET_PORT)${NC}"
    ERRORS=$((ERRORS+1))
fi

# Check if Password Auth is disabled
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config; then
     echo -e "✅ SSH Password Auth: \t\t${GREEN}DISABLED${NC}"
else
     echo -e "❌ SSH Password Auth: \t\t${RED}ENABLED (Security Risk!)${NC}"
     ERRORS=$((ERRORS+1))
fi

# 3. Check Firewall (UFW)
UFW_STATUS=$(ufw status | grep "Status: active")
if [[ ! -z "$UFW_STATUS" ]]; then
    echo -e "✅ Firewall Status: \t\t${GREEN}ACTIVE${NC}"
    # Check if port is allowed
    if ufw status | grep -q "$TARGET_PORT/tcp"; then
         echo -e "✅ Firewall Port $TARGET_PORT: \t${GREEN}ALLOWED${NC}"
    else
         echo -e "❌ Firewall Port $TARGET_PORT: \t${RED}BLOCKED${NC}"
         ERRORS=$((ERRORS+1))
    fi
else
    echo -e "❌ Firewall Status: \t\t${RED}INACTIVE${NC}"
    ERRORS=$((ERRORS+1))
fi

# 4. Check Swap
if [ -f /cryptswap ] || grep -q "/dev/dm-" /proc/swaps; then
    SWAP_SIZE=$(free -h | grep Swap | awk '{print $2}')
    echo -e "✅ Swap ($SWAP_SIZE): \t\t${GREEN}ACTIVE & ENCRYPTED${NC}"
else
    # Check if swap was intentionally disabled (High RAM)
    RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
    if [ "$RAM_MB" -gt 16000 ]; then
        echo -e "✅ Swap: \t\t\t${GREEN}DISABLED (High RAM)${NC}"
    else
        echo -e "❌ Swap: \t\t\t${RED}MISSING (Low RAM but no Swap)${NC}"
        ERRORS=$((ERRORS+1))
    fi
fi

# 5. Check Docker
if systemctl is-active --quiet docker; then
    DOCKER_VER=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo -e "✅ Docker Engine ($DOCKER_VER): \t${GREEN}RUNNING${NC}"
else
    echo -e "❌ Docker Engine: \t\t${RED}NOT RUNNING${NC}"
    ERRORS=$((ERRORS+1))
fi

# 6. Check Watchdog
if systemctl is-active --quiet watchdog.timer; then
    echo -e "✅ Security Watchdog: \t\t${GREEN}ACTIVE${NC}"
else
    echo -e "❌ Security Watchdog: \t\t${RED}INACTIVE${NC}"
    ERRORS=$((ERRORS+1))
fi

echo "---------------------------------------------------"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}🎉 FINAL VERIFICATION SUCCESSFUL! Zero Issues found.${NC}"
    exit 0
else
    echo -e "${RED}🚨 FINAL VERIFICATION FAILED! Found $ERRORS Issues.${NC}"
    exit 1
fi
