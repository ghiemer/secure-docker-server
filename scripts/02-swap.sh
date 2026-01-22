#!/bin/bash
set -e
set -x  # Enable full command tracing for logging

# RAM in MB ermitteln
RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
SWAP_THRESHOLD=16000 # 16 GB

echo "💾 Prüfe Speicher (RAM: ${RAM_MB} MB)..."

if [ "$RAM_MB" -gt "$SWAP_THRESHOLD" ]; then
    echo "🚀 Viel RAM vorhanden (>16GB). Deaktiviere Swap aus Sicherheitsgründen."
    swapoff -a || true
    # Entferne Swap aus fstab
    sed -i '/swap/d' /etc/fstab
    rm -f /swapfile
    echo "✅ Swap deaktiviert."
else
    echo "🔒 Wenig RAM. Konfiguriere VERSCHLÜSSELTEN Swap."
    
    # Prüfen ob schon aktiv
    if grep -q "cryptswap" /etc/crypttab; then
        echo "✅ Verschlüsselter Swap ist bereits konfiguriert."
        exit 0
    fi

    # Alten Swap ausmachen
    swapoff -a || true
    sed -i '/swap/d' /etc/fstab
    rm -f /swapfile

    # 4GB Container erstellen
    echo "   Erstelle 4GB Swap-Datei (Das dauert kurz)..."
    dd if=/dev/zero of=/cryptswap bs=1M count=4096 status=none
    chmod 600 /cryptswap

    # Crypttab Eintrag (Formatiert bei jedem Boot neu mit Zufallskey -> Daten weg beim Reboot)
    echo "   ✍️  Adding entry to /etc/crypttab"
    echo "cryptswap /cryptswap /dev/urandom swap,offset=8,cipher=aes-xts-plain64,size=256" >> /etc/crypttab

    # Fstab Eintrag
    echo "   ✍️  Adding entry to /etc/fstab"
    echo "/dev/mapper/cryptswap none swap sw 0 0" >> /etc/fstab

    echo "✅ Encrypted Swap konfiguriert (Aktiv nach Reboot)."
fi
