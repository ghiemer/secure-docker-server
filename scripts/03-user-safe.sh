#!/bin/bash
set -e

YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${YELLOW}---------------------------------------------------${NC}"
echo -e "${YELLOW}👤 BENUTZER EINRICHTUNG & SSH ABSICHERUNG${NC}"
echo -e "${YELLOW}---------------------------------------------------${NC}"
echo "Wir erstellen einen Admin-User und deaktivieren Root."
echo "⚠️  WARNUNG: Du benötigst deinen SSH Public Key!"
echo ""

# 1. User anlegen
read -p "Gewünschter Username (z.B. admin): " NEW_USER
if id "$NEW_USER" &>/dev/null; then
    echo "ℹ️  User $NEW_USER existiert bereits."
else
    adduser --gecos "" "$NEW_USER"
    usermod -aG sudo "$NEW_USER"
fi

# Speichere User für spätere Docker Group
echo "$NEW_USER" > /root/.server_setup_user

# 2. Key abfragen
echo ""
echo "Bitte füge jetzt deinen SSH PUBLIC KEY ein (beginnt mit ssh-rsa oder ssh-ed25519):"
read -r SSH_KEY

if [[ ! "$SSH_KEY" =~ ^ssh- ]]; then
    echo -e "${RED}🚨 ERROR: Das sieht nicht nach einem gültigen SSH Key aus!${NC}"
    exit 1
fi

mkdir -p /home/$NEW_USER/.ssh
echo "$SSH_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys

# 3. Verifikation
echo -e "\n${YELLOW}🧪 SICHERHEITSPRÜFUNG STARTET...${NC}"
echo "Wir starten einen temporären SSH Server auf PORT 2222."
echo ""

cat > /etc/ssh/sshd_config_verify <<EOF
Port 2222
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AllowUsers $NEW_USER
Subsystem sftp /usr/lib/openssh/sftp-server
EOF

/usr/sbin/sshd -f /etc/ssh/sshd_config_verify

echo -e "${GREEN}👉 HANDLUNG ERFORDERLICH:${NC}"
echo "1. Öffne ein NEUES Terminal auf deinem PC."
echo "2. Verbinde dich:  ssh -p 2222 $NEW_USER@$(curl -s ifconfig.me)"
echo "3. Wenn der Login klappt, führe im neuen Fenster aus:  touch /tmp/ssh_verified"
echo ""
echo "⏳ Warte auf Verifikation (Max 120 Sekunden)..."

count=0
while [ $count -lt 120 ]; do
    if [ -f /tmp/ssh_verified ]; then
        echo -e "${GREEN}✅ Login Verifiziert!${NC}"
        break
    fi
    sleep 1
    ((count++))
    echo -n "."
done

if [ ! -f /tmp/ssh_verified ]; then
    echo -e "\n${RED}🚨 TIMEOUT! Verifikation fehlgeschlagen.${NC}"
    echo "Änderungen werden verworfen. Dein aktueller Root-Zugang bleibt erhalten."
    kill $(pgrep -f "sshd_config_verify") || true
    exit 1
fi

# 4. Finalisieren
echo "🔒 Sperre SSH (Root Login OFF, Password OFF)..."
mv /etc/ssh/sshd_config_verify /etc/ssh/sshd_config
sed -i 's/Port 2222/Port 22/' /etc/ssh/sshd_config
systemctl restart ssh
kill $(pgrep -f "sshd_config_verify") || true
rm -f /tmp/ssh_verified

echo "✅ SSH Hardening abgeschlossen."
