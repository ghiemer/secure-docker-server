#!/bin/bash
set -e
set -x  # Enable full command tracing for logging

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
echo -n "Gewünschter Username (z.B. admin): "
read -r NEW_USER
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
    echo -n "Möchtest du diesen Key für '$NEW_USER' verwenden? [J/n]: "
    read -r USE_EXISTING
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
echo "   ✍️  Writing key to /home/$NEW_USER/.ssh/authorized_keys"
echo "$SSH_KEY" > /home/$NEW_USER/.ssh/authorized_keys
chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
chmod 700 /home/$NEW_USER/.ssh
chmod 600 /home/$NEW_USER/.ssh/authorized_keys


# 3. Port Auswahl (Vorziehen für Klarheit)
echo ""
echo "---------------------------------------------------"
echo -n "Soll der Standard SSH Port 22 verwendet werden? [J/n]: "
read -r PORT_CHOICE
SSH_PORT=22

if [[ "$PORT_CHOICE" =~ ^[nN]$ ]]; then
    while true; do
        echo -n "Bitte neuen SSH Port eingeben (1024-65535): "
        read -r SSH_PORT
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





# 4. Verifikation ("Live" Test)
echo -e "\n${YELLOW}🧪 SICHERHEITSPRÜFUNG STARTET...${NC}"

# Verification Port IST der gewählte Port
VERIFY_PORT=$SSH_PORT

echo "Wir testen die neue Konfiguration direkt am laufenden SSH-Server."
echo "Deine aktuelle Verbindung bleibt bestehen (Reload statt Restart)."
echo ""

# 1. Backup Current Config
echo "   📦 Backing up current config -> /etc/ssh/sshd_config.bak"
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 2. Write NEW Config directly to production file
echo "   ✍️  Writing new hardened config -> /etc/ssh/sshd_config"
cat > /etc/ssh/sshd_config <<EOF
Port $VERIFY_PORT
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

# 3. Reload SSH to apply changes (Does NOT kill active connections)
echo "   🔄 Reloading SSH configuration..."
systemctl reload ssh

# Define Restore Function (Revert to backup)
revert_config() {
    echo ""
    echo -e "${YELLOW}⏪ REVERTING sshd_config to previous state...${NC}"
    cp /etc/ssh/sshd_config.bak /etc/ssh/sshd_config
    systemctl reload ssh
    echo "✅ Configuration restored. You can fix issues and run the script again."
}

echo -e "${GREEN}👉 HANDLUNG ERFORDERLICH:${NC}"
echo ""
echo "#####################################################################"
echo "#                                                                   #"
echo "#  1. Öffne ein NEUES Terminal auf deinem PC (nicht hier drinnen!)  #"
echo "#                                                                   #"
echo "#  2. Kopiere diesen Befehl und führe ihn im neuen Fenster aus :    #"
echo "#                                                                   #"
echo "   ssh -p $VERIFY_PORT $NEW_USER@$(curl -4 -s ifconfig.me)"
echo "#                                                                   #"
echo "#  3. Prüfe deine SUDO-Rechte (WICHTIG!):                           #"
echo "#                                                                   #"
echo "#     Führe diesen Befehl aus, um das Setup zu bestätigen:          #"
echo "#                                                                   #"
echo "   sudo touch /root/setup_verified"
echo "#                                                                   #"
echo "#     (Wenn das klappt, hast du erfolgreich Sudo-Rechte)"            #"
echo "#                                                                   #"
echo "#####################################################################"
echo ""
echo "Drücke [ENTER], sobald du die Datei '/root/setup_verified' erstellt hast."
echo "Das Skript wartet hier..."

# Loop until verified or aborted
while true; do
    read -r

    if [ -f /root/setup_verified ]; then
        echo -e "${GREEN}✅ Login & Sudo Verifiziert!${NC}"
        # Success! Finalize.
        rm -f /etc/ssh/sshd_config.bak
        rm -f /root/setup_verified
        echo "✅ SSH Hardening dauerhaft aktiviert."
        break
    else
        echo -e "\n${RED}🚨 DATEI NICHT GEFUNDEN! (/root/setup_verified)${NC}"
        echo "Hast du 'sudo touch /root/setup_verified' erfolgreich ausgeführt?"
        echo -n "Möchtest du es nochmal versuchen? [J/n]: "
        read -r RETRY
        if [[ "$RETRY" =~ ^[nN]$ ]]; then
            echo "Abbruch durch Benutzer."
            revert_config
            exit 1
        fi
        echo "🔄 Warte erneut. Drücke [ENTER] wenn bereit..."
    fi
done
