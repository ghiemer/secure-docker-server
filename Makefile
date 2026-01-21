SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := install

# Emoji Helpers
MSG_START = @echo -e "\n🔹 $(1)..."
MSG_OK    = @echo -e "✅ $(1) OK"
MSG_ERR   = @echo -e "🚨 ERROR: $(1)"

install: preflight system swap user harden docker watchdog
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
	$(call MSG_START, "Hardening Host (Firewall, Kernel, Fail2Ban, Auditd)")
	
	# 1. Sysctl
	@cp configs/sysctl.conf /etc/sysctl.d/99-security.conf
	@sysctl --system > /dev/null
	
	# 2. Fail2Ban
	@cp configs/jail.local /etc/fail2ban/jail.local
	@systemctl restart fail2ban
	
	# 3. Auditd Rules
	@cp configs/audit.rules /etc/audit/rules.d/audit.rules
	@augenrules --load
	
	# 4. Unattended Upgrades Config
	@cp configs/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades
	
	# 5. Firewall Setup
	@ufw --force reset > /dev/null
	@ufw default deny incoming
	@ufw default allow outgoing
	@ufw allow 22/tcp
	@ufw allow 80/tcp
	@ufw allow 443/tcp
	@echo "y" | ufw enable
	
	$(call MSG_OK, "System Hardened")

docker:
	$(call MSG_START, "Installing Hardened Docker Engine")
	@./scripts/04-docker.sh

watchdog:
	$(call MSG_START, "Installing Security Watchdog")
	@cp watchdog/port-monitor.sh /usr/local/bin/security-watchdog
	@chmod +x /usr/local/bin/security-watchdog
	@cp watchdog/watchdog.service /etc/systemd/system/
	@cp watchdog/watchdog.timer /etc/systemd/system/
	@systemctl daemon-reload
	@systemctl enable --now watchdog.timer
	$(call MSG_OK, "Watchdog active")
