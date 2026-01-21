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
# Wir nutzen 'script', um TTY (Interaktivität) zu erhalten und trotzdem zu loggen
# Da 'script' alles aufzeichnet, müssen wir das Logfile danach bereinigen (Masking)
if command -v script >/dev/null; then
    script -q -c "make install" /dev/null | tee >(mask_secrets >> "$LOGFILE")
    EXIT_CODE=${PIPESTATUS[0]}
else
    # Fallback falls 'script' fehlt (unwahrscheinlich auf Ubuntu)
    make install 2>&1 | tee >(mask_secrets >> "$LOGFILE")
    EXIT_CODE=${PIPESTATUS[0]}
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ SETUP SUCCESSFULLY COMPLETED!${NC}"
    echo "Please check $LOGFILE for details."
else
    echo -e "${RED}🚨 SETUP FAILED!${NC}"
    echo "Check $LOGFILE for the error message."
fi

exit $EXIT_CODE
