#!/bin/bash
set -e

echo "📦 System-Update und Installation der Abhängigkeiten..."

# 1. Update Apt
export DEBIAN_FRONTEND=noninteractive
apt-get update -q
apt-get dist-upgrade -y -q

# 2. Install Tools
# 'haveged' ist wichtig für Entropie (Verschlüsselung) auf virtuellen Servern
apt-get install -y -q \
    curl \
    git \
    ufw \
    fail2ban \
    auditd \
    audispd-plugins \
    cryptsetup \
    net-tools \
    jq \
    haveged \
    unattended-upgrades \
    apt-listchanges

# 3. Enable Haveged (Entropy Daemon)
systemctl enable --now haveged

# 4. Configure Unattended Upgrades (Sicherheitsupdates automatisch installieren)
# Wir kopieren später die Config, aber aktivieren es hier schon mal
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades

echo "✅ System-Tools installiert."
