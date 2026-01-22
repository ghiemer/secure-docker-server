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
echo "---------------------------------------------------"
if [ -f /root/.ssh/authorized_keys ] && [ -s /root/.ssh/authorized_keys ]; then
    echo "🔑 VORHANDENER SSH KEY GEFUNDEN (z.B. von Hetzner)."
    read -p "Möchtest du diesen Key für '$NEW_USER' verwenden? [J/n]: " USE_EXISTING
else
    USE_EXISTING="n"
fi

if [[ "$USE_EXISTING" =~ ^[nN]$ ]]; then
    echo ""
    echo "Bitte füge jetzt deinen SSH PUBLIC KEY ein (beginnt mit ssh-rsa oder ssh-ed25519):"
    read -r SSH_KEY
    
    if [[ ! "$SSH_KEY" =~ ^ssh- ]]; then
        echo -e "${RED}🚨 ERROR: Das sieht nicht nach einem gültigen SSH Key aus!${NC}"
        exit 1
    fi
else
    echo "✅ Übernehme vorhandene Keys von root..."
    SSH_KEY=$(cat /root/.ssh/authorized_keys)
fi

mkdir -p /home/$NEW_USER/.ssh
echo "$SSH_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys


# 3. Port Auswahl (Vorziehen für Klarheit)
echo ""
echo "---------------------------------------------------"
read -p "Soll der Standard SSH Port 22 verwendet werden? [J/n]: " PORT_CHOICE
SSH_PORT=22

if [[ "$PORT_CHOICE" =~ ^[nN]$ ]]; then
    while true; do
        read -p "Bitte neuen SSH Port eingeben (1024-65535): " SSH_PORT
        if [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && [ "$SSH_PORT" -ge 1024 ] && [ "$SSH_PORT" -le 65535 ]; then
            echo "✅ Neuer SSH Port: $SSH_PORT"
            break
        else
            echo "⚠️ Ungültiger Port. Bitte eine Zahl zwischen 1024 und 65535."
        fi
    done
fi
# Speichere Port für Makefile (UFW etc)
echo "$SSH_PORT" > /root/.server_setup_port


# 4. Verifikation
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
echo "2. Verbinde dich:  ssh -p 2222 $NEW_USER@$(curl -4 -s ifconfig.me)"
echo "3. Prüfe deine Rechte: 'sudo whoami' (Muss 'root' zurückgeben)"
echo "4. WENN alles klappt, führe im neuen Fenster aus:  touch /tmp/ssh_verified"
echo ""
echo "⚠️  WICHTIG: Das Skript wartet, bis DU bestätigst."
read -p "Drücke [ENTER], sobald du erfolgreich eingeloggt bist und die Datei erstellt hast..."

if [ ! -f /tmp/ssh_verified ]; then
    echo -e "\n${RED}🚨 DATEI NICHT GEFUNDEN! (/tmp/ssh_verified)${NC}"
    echo "Sicher, dass der Login geklappt hat?"
    read -p "Möchtest du es nochmal versuchen? [J/n]: " RETRY
    if [[ "$RETRY" =~ ^[nN]$ ]]; then
        echo "Abbruch durch Benutzer."
        kill $(pgrep -f "sshd_config_verify") || true
        exit 1
    fi
    # Simple retry loop handled by user simply creating the file and pressing enter again? 
    # For simplicity, if check fails, we give one chance or just exit. 
    # Let's make it a simple check. If missing, fail.
    # User can restart script easily.
    echo "Bitte starte das Skript neu, wenn du bereit bist."
    kill $(pgrep -f "sshd_config_verify") || true
    exit 1
fi

echo -e "${GREEN}✅ Login Verifiziert!${NC}"

# 5. Finalisieren
echo "🔒 Sperre SSH (Root Login OFF, Password OFF, Port $SSH_PORT)..."
mv /etc/ssh/sshd_config_verify /etc/ssh/sshd_config

# Konfiguriere Port final
sed -i "s/Port 2222/Port $SSH_PORT/" /etc/ssh/sshd_config
systemctl restart ssh
kill $(pgrep -f "sshd_config_verify") || true
rm -f /tmp/ssh_verified

echo "✅ SSH Hardening abgeschlossen."
