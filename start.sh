#!/bin/bash
set -o pipefail

# Konfiguration
LOGFILE="install_$(date +%Y%m%d_%H%M%S).log"
touch "$LOGFILE"
chmod 600 "$LOGFILE"

# Farben laden
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 STARTING SECURE SERVER SETUP${NC}"
echo "📝 Logfile: $LOGFILE (Secrets are masked *****)"

# Funktion zum Maskieren von Secrets im Log
# Filtert: SSH Keys, Private Keys, Passwörter die versehentlich ausgegeben werden könnten
mask_secrets() {
    sed -u -e 's/ssh-rsa AAAA[0-9a-zA-Z\+\/]*\+/ssh-rsa [MASKED_PUBLIC_KEY]/g' \
           -e 's/ssh-ed25519 AAAA[0-9a-zA-Z\+\/]*\+/ssh-ed25519 [MASKED_PUBLIC_KEY]/g' \
           -e 's/BEGIN OPENSSH PRIVATE KEY/BEGIN [MASKED] KEY/g' \
           -e 's/password=[^ ]*/password=******/g'
}

# Wrapper um Make aufzurufen
# Wir leiten stderr (Trace Output durch set -x) NUR in das Logfile.
# Wir leiten stdout (Echo Output) in das Terminal UND das Logfile.
# 'script' wird nicht mehr benötigt, da wir Streams direkt trennen.

if command -v make >/dev/null; then
    # Start: ( stdout -> tee ) & ( stderr -> log )
    # Syntax: Command > >(tee -a log) 2>> log
    # mask_secrets wird dazwischen geschaltet
    
    ( make install ) \
        > >(tee -a >(mask_secrets >> "$LOGFILE")) \
        2> >(mask_secrets >> "$LOGFILE")
        
    EXIT_CODE=$?
else
    echo "🚨 ERROR: 'make' command not found."
    EXIT_CODE=1
fi

echo ""

if [ $EXIT_CODE -eq 0 ]; then
    # Konfigurationen auslesen
    TARGET_USER=$(cat /root/.server_setup_user 2>/dev/null || echo "Unknown")
    TARGET_PORT=$(cat /root/.server_setup_port 2>/dev/null || echo "22")
    DOCKER_VERSION=$(docker --version 2>/dev/null || echo "Not Installed")

    echo -e "${GREEN}✅ SETUP SUCCESSFULLY COMPLETED!${NC}"
    echo "---------------------------------------------------------"
    echo -e "👤 **Benutzer:**       ${GREEN}$TARGET_USER${NC}"
    echo -e "🔑 **SSH Port:**       ${GREEN}$TARGET_PORT${NC} (Wichtig für nächsten Login!)"
    echo -e "🐳 **Docker:**         $DOCKER_VERSION"
    echo -e "🔥 **Firewall:**       Aktiv (Ports: $TARGET_PORT, 80, 443 allow)"
    echo -e "🛡️  **Security:**       Fail2Ban active, Swap encrypted, Kernel hardened"
    echo "---------------------------------------------------------"
    echo -e "👇 **NÄCHSTE SCHRITTE:**"
    echo "1. Server neustarten: 'reboot'"
    echo "2. Neu verbinden:     'ssh -p $TARGET_PORT $TARGET_USER@<DEINE-IP>'"
    echo "---------------------------------------------------------"
    echo "Please check $LOGFILE for full logs."
else
    echo -e "${RED}🚨 SETUP FAILED!${NC}"
    echo "Check $LOGFILE for the error message."
fi

exit $EXIT_CODE
