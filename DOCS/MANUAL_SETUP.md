# 🛠️ Manual Installation (Step by Step)

This guide describes exactly the steps that are normally performed automatically by the `start.sh` script. Use this guide if you want to understand "what's under the hood" or if you want to set up the server manually.

> **Note:** All commands must be executed as **ROOT**.

---

## 1. System & Dependencies

First, we update the system and install necessary tools.

```bash
# Updates
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get dist-upgrade -y

# Install tools
apt-get install -y curl git ufw fail2ban auditd audispd-plugins cryptsetup net-tools jq haveged unattended-upgrades apt-listchanges

# Enable Entropy Daemon (important for encryption)
systemctl enable --now haveged

# Enable automatic updates
echo "unattended-upgrades unattended-upgrades/enable_auto_updates boolean true" | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
```

---

## 2. Encrypted Swap (Memory Extension)

We set up swap memory that is re-encrypted with a **random key** at every boot. This prevents sensitive data from ever remaining permanently readable on the disk.

**Only strictly necessary if RAM < 16GB.**

```bash
# 1. Disable old swaps
swapoff -a
rm -f /swapfile

# 2. Create container (4GB)
dd if=/dev/zero of=/cryptswap bs=1M count=4096 status=none
chmod 600 /cryptswap

# 3. Configure Crypttab (Random key at every boot)
echo "cryptswap /cryptswap /dev/urandom swap,offset=8,cipher=aes-xts-plain64,size=256" >> /etc/crypttab

# 4. Fstab entry
echo "/dev/mapper/cryptswap none swap sw 0 0" >> /etc/fstab

# Note: This becomes active only after reboot.
```

---

## 3. User & SSH Hardening

We replace the `root` login with a personalized admin user with SSH key.

### 3.1 Create User
Replace `admin` with your desired username.

```bash
adduser admin
usermod -aG sudo admin
```

### 3.2 Add SSH Keys
You must copy your **local public key** (`id_rsa.pub` or `id_ed25519.pub`) to the server.

```bash
mkdir -p /home/admin/.ssh
echo "YOUR_SSH_PUBLIC_KEY_HERE" > /home/admin/.ssh/authorized_keys
chown -R admin:admin /home/admin/.ssh
chmod 700 /home/admin/.ssh
chmod 600 /home/admin/.ssh/authorized_keys
```

### 3.3 Secure SSH Service
Edit `/etc/ssh/sshd_config` and set the following values (or add them):

```ini
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
AllowUsers admin
```

Then restart: `systemctl restart ssh`

---

## 4. System Hardening

We harden the kernel, enable the firewall, and configure Fail2Ban.

### 4.1 Kernel Hardening (Sysctl)
Create `/etc/sysctl.d/99-security.conf`:

```ini
# IP Spoofing Protection
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
# No Source Routes
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
# No Redirects (Anti-MITM)
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
# Disable IPv6
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
# Logging
kernel.dmesg_restrict = 1
```
Apply: `sysctl --system`

### 4.2 Fail2Ban
Create `/etc/fail2ban/jail.local`:

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
Restart: `systemctl restart fail2ban`

### 4.3 Firewall (UFW)
We block everything except SSH, HTTP, and HTTPS.

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable  # Confirm with 'y'
```

---

## 5. Docker Installation & Security

### 5.1 Installation
```bash
curl -fsSL https://get.docker.com | sh
```

### 5.2 Hardening (Daemon Config)
Create `/etc/docker/daemon.json` to limit logs and restrict privileges:

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

### 5.3 Add User to Group
```bash
usermod -aG docker admin
systemctl restart docker
```

---

## 6. Security Watchdog (Optional)

A script that checks every 5 minutes if unwanted ports are open.

1.  Create script `/usr/local/bin/security-watchdog` (see `watchdog/port-monitor.sh` in repo for content).
2.  Make executable: `chmod +x /usr/local/bin/security-watchdog`
3.  Create service `/etc/systemd/system/watchdog.service`.
4.  Create timer `/etc/systemd/system/watchdog.timer`.
5.  Enable: `systemctl enable --now watchdog.timer`.

---

## 7. Conclusion

Restart server:
```bash
reboot
```

Afterward, you can **only** login as `admin` using your SSH key.
