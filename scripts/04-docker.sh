#!/bin/bash
set -e
set -x  # Enable full command tracing for logging

echo "🐳 Installiere Docker Engine..."

# 1. Docker Repo hinzufügen (falls nicht da)
if ! command -v docker >/dev/null; then
    curl -fsSL https://get.docker.com | sh
else
    echo "   Docker ist bereits installiert."
fi

# 2. Hardening Config anwenden
# 2. Hardening Config anwenden
echo "   ✍️  Copying configs/daemon.json -> /etc/docker/daemon.json"
mkdir -p /etc/docker
cp configs/daemon.json /etc/docker/daemon.json

# 3. Service Neustart
systemctl restart docker

# 4. User zur Gruppe hinzufügen
# Wir lesen den User aus der temporären Datei, die 03-user-safe.sh erstellt hat
if [ -f /root/.server_setup_user ]; then
    TARGET_USER=$(cat /root/.server_setup_user)
    echo "   Füge User '$TARGET_USER' zur Docker-Gruppe hinzu..."
    usermod -aG docker "$TARGET_USER"
else
    echo "⚠️ WARNUNG: Konnte User nicht finden. Bitte manuell: 'usermod -aG docker DEINUSER' ausführen."
fi

echo "✅ Docker installiert und gehärtet."
