SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := install
.PHONY: install preflight system swap user harden docker watchdog verify

# Emoji Helpers
MSG_START = @echo -e "\n🔹 $(1)..."
MSG_OK    = @echo -e "✅ $(1) OK"
MSG_ERR   = @echo -e "🚨 ERROR: $(1)"

install: preflight system swap user harden docker watchdog verify
	@echo "------------------------------------------------"
	@echo "🎉 SERVER READY. REBOOT REQUIRED."

preflight:
	$(call MSG_START, "Running Pre-Flight Checks")
	@chmod +x scripts/*.sh
	@./scripts/00-preflight.sh

system:
	$(call MSG_START, "Updating System and Dependencies")
	@./scripts/01-system.sh

swap:
	$(call MSG_START, "Configuring Memory and Swap")
	@./scripts/02-swap.sh

user:
	$(call MSG_START, "Setting up Admin User and SSH Lock")
	@./scripts/03-user-safe.sh

harden:
	$(call MSG_START, "Hardening Host: Firewall - Kernel - Fail2Ban - Auditd")
	
	# 1. Sysctl
	@echo "   ✍️  Copying sysctl.conf -> /etc/sysctl.d/99-security.conf"
	@cp configs/sysctl.conf /etc/sysctl.d/99-security.conf
	@echo "   🔄 Reloading system settings..."
	@sysctl --system > /dev/null
	
	# 2. Fail2Ban
	@echo "   ✍️  Copying jail.local -> /etc/fail2ban/jail.local"
	@cp configs/jail.local /etc/fail2ban/jail.local
	@SSH_PORT=$$(cat /root/.server_setup_port 2>/dev/null || echo 22); \
	 echo "   ✏️  Setting Fail2Ban SSH port to $$SSH_PORT..."; \
	 sed -i "s/^port *= *ssh/port = $$SSH_PORT/" /etc/fail2ban/jail.local
	@echo "   🔄 Restarting Fail2Ban..."
	@systemctl restart fail2ban
	
	# 3. Auditd Rules
	@mkdir -p /etc/docker
	@echo "   ✍️  Copying audit.rules -> /etc/audit/rules.d/audit.rules"
	@cp configs/audit.rules /etc/audit/rules.d/audit.rules
	@echo "   🔄 Loading Audit rules..."
	@augenrules --load || true
	
	# 4. Unattended Upgrades Config
	@echo "   ✍️  Copying 50unattended-upgrades -> /etc/apt/apt.conf.d/50unattended-upgrades"
	@cp configs/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
	
	# 5. Firewall Setup
	@echo "   🔥 Resetting Firewall..."
	@ufw --force reset > /dev/null
	@ufw default deny incoming
	@ufw default allow outgoing
	@SSH_PORT=$$(cat /root/.server_setup_port 2>/dev/null || echo 22); \
	 ufw allow $$SSH_PORT/tcp
	@ufw allow 80/tcp
	@ufw allow 443/tcp
	@echo "y" | ufw enable
	
	$(call MSG_OK, "System Hardened")

docker:
	$(call MSG_START, "Installing Hardened Docker Engine")
	@./scripts/04-docker.sh

watchdog:
	$(call MSG_START, "Installing Security Watchdog")
	@echo "   ✍️  Installing script -> /usr/local/bin/security-watchdog"
	@cp watchdog/port-monitor.sh /usr/local/bin/security-watchdog
	@chmod +x /usr/local/bin/security-watchdog
	@SSH_PORT=$$(cat /root/.server_setup_port 2>/dev/null || echo 22); \
	 echo "   ✏️  Configuring allowed port $$SSH_PORT in watchdog..."; \
	 sed -i "s/ALLOWED_PORTS=\"22/ALLOWED_PORTS=\"$$SSH_PORT/" /usr/local/bin/security-watchdog
	@echo "   ✍️  Installing systemd units..."
	@cp watchdog/watchdog.service /etc/systemd/system/
	@cp watchdog/watchdog.timer /etc/systemd/system/
	@systemctl daemon-reload
	@systemctl enable --now watchdog.timer
	$(call MSG_OK, "Watchdog active")

verify:
	$(call MSG_START, "Running Final System Audit")
	@chmod +x scripts/99-verify.sh
	@./scripts/99-verify.sh

