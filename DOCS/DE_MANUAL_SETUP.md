# 🛠️ Manuelle Installation (Schritt für Schritt)

Diese Anleitung beschreibt exakt die Schritte, die normalerweise durch das `start.sh`-Skript automatisiert durchgeführt werden. Verwende diese Anleitung, wenn du verstehen willst, was "unter der Haube" passiert, oder wenn du den Server manuell aufsetzen möchtest.

> **Hinweis:** Alle Befehle müssen als **ROOT** ausgeführt werden.

---

## 1. System & Abhängigkeiten

Zuerst bringen wir das System auf den neuesten Stand und installieren notwendige Werkzeuge.

```bash
# Updates
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get dist-upgrade -y

# Tools installieren
apt-get install -y curl git ufw fail2ban auditd audispd-plugins cryptsetup net-tools jq haveged unattended-upgrades apt-listchanges

# Entropy-Daemon aktivieren (wichtig für Verschlüsselung)
systemctl enable --now haveged

# Automatische Updates aktivieren
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
```

---

## 2. Verschlüsselter Swap (Arbeitsspeicher-Erweiterung)

Wir richten einen Swap-Speicher ein, der bei jedem Neustart mit einem **zufälligen Key** neu verschlüsselt wird. So landen niemals sensible Daten dauerhaft lesbar auf der Festplatte.

**Nur durchführen, wenn RAM < 16GB ist.**

```bash
# 1. Alte Swaps deaktivieren
swapoff -a
rm -f /swapfile

# 2. Container erstellen (4GB)
dd if=/dev/zero of=/cryptswap bs=1M count=4096 status=none
chmod 600 /cryptswap

# 3. Crypttab konfigurieren (Zufalls-Key bei jedem Boot)
echo "cryptswap /cryptswap /dev/urandom swap,offset=8,cipher=aes-xts-plain64,size=256" >> /etc/crypttab

# 4. Fstab Eintrag
echo "/dev/mapper/cryptswap none swap sw 0 0" >> /etc/fstab

# Hinweis: Aktiv wird dies erst nach dem Reboot.
```

---

## 3. Benutzer & SSH Hardening

Wir ersetzen den `root`-Login durch einen personalisierten Admin-User mit SSH-Key.

### 3.1 User erstellen
Ersetze `admin` durch deinen Wunschnamen.

```bash
adduser admin
usermod -aG sudo admin
```

### 3.2 SSH Keys hinterlegen
Du musst deinen **lokalen Public Key** (`id_rsa.pub` oder `id_ed25519.pub`) auf den Server kopieren.

```bash
mkdir -p /home/admin/.ssh
echo "DEIN_SSH_PUBLIC_KEY_HIER" > /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
```

### 3.3 SSH Dienst absichern
Bearbeite `/etc/ssh/sshd_config` und setze folgende Werte (oder füge sie hinzu):

```ini
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AllowUsers admin
```

Danach Neustart: `systemctl restart ssh`

---

## 4. System Hardening

Wir härten den Kernel, aktivieren die Firewall und konfigurieren Fail2Ban.

### 4.1 Kernel Hardening (Sysctl)
Erstelle `/etc/sysctl.d/99-security.conf`:

```ini
# IP Spoofing Schutz
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# Keine Source Routes
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
# Keine Redirects (Anti-MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
# IPv6 deaktivieren
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
# Logging
kernel.dmesg_restrict = 1
```
Anwenden: `sysctl --system`

### 4.2 Fail2Ban
Erstelle `/etc/fail2ban/jail.local`:

```ini
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
backend = systemd

[recidive]
enabled  = true
banaction = ufw
bantime  = 1w
findtime = 1d
maxretry = 3
```
Neustart: `systemctl restart fail2ban`

### 4.3 Firewall (UFW)
Wir sperren alles, außer SSH, HTTP und HTTPS.

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable  # Mit 'y' bestätigen
```

---

## 5. Docker Installation & Security

### 5.1 Installation
```bash
curl -fsSL https://get.docker.com | sh
```

### 5.2 Hardening (Daemon Config)
Erstelle `/etc/docker/daemon.json`, um Logs zu limitieren und Privilegien zu beschränken:

```json
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "no-new-privileges": true,
    "userland-proxy": false,
    "live-restore": true,
    "ipv6": false,
    "icc": false
}
```

### 5.3 User hinzufügen
```bash
usermod -aG docker admin
systemctl restart docker
```

---

## 6. Security Watchdog (Optional)

Ein Skript, das alle 5 Minuten prüft, ob unerwünschte Ports offen sind.

1.  Skript `/usr/local/bin/security-watchdog` erstellen (Inhalt siehe `watchdog/port-monitor.sh` im Repo).
2.  Ausführbar machen: `chmod +x /usr/local/bin/security-watchdog`
3.  Service anlegen `/etc/systemd/system/watchdog.service`.
4.  Timer anlegen `/etc/systemd/system/watchdog.timer`.
5.  Aktivieren: `systemctl enable --now watchdog.timer`.

---

## 7. Abschluss

Server neustarten:
```bash
reboot
```

Danach kannst du dich **nur noch** als `admin` mit deinem SSH-Key anmelden.
