# 🛡️ Secure Docker Server Setup (Hetzner Edition)

> 🇩🇪 **[Deutsche Version](DE_README.md)**
>
> 🛠️ **[Manual Installation Guide](DOCS/MANUAL_SETUP.md)**

This repository transforms a fresh Ubuntu 24.04 server into a **hardened fortress** for Docker applications. It automates best practices for security, firewalling, and system configuration.

## 🎯 Features

*   ✅ **OS Hardening:** Sysctl Tweaks, Auditd, Secure Swap (encrypted).
*   ✅ **SSH Safe-Lock:** Interactive SSH key setup with "Anti-Lockout Guarantee".
*   ✅ **Firewall:** UFW pre-configured (only 22, 80, 443).
*   ✅ **Docker Security:** Daemon Hardening, No-New-Privileges, Log Limits.
*   ✅ **Interactive Port Selection:** Choose your own secure SSH port (e.g., 22222) instead of the default 22.
*   ✅ **Final Verification:** Runs a comprehensive audit (User, Port, Firewall, Docker) to confirm system integrity before finishing.
*   ✅ **Docker Compose:** Automatically installs the modern Docker Compose V2 Plugin (`docker compose`).
*   ✅ **Watchdog:** Monitors for accidentally opened ports.
*   ✅ **Logging:** Writes a logfile (`setup.log`) and masks secrets (*****).



## 🚀 Installation

### Step 1: Create Server

> [!TIP]
> # 🎁 €20 HETZNER STARTING CREDIT GIFT
>
> Use this link to register and receive **€20 credit immediately** for all cloud products:
>
> 👉 **[https://hetzner.cloud/?ref=6uP8iWBs6GUZ](https://hetzner.cloud/?ref=6uP8iWBs6GUZ)**
>
> **Your Benefit:** €20 gift to start.
> **Our Support:** Once you spend €10, we receive €10 credit as a thank you for this project. **Win-Win!** 🤝

Create a server at Hetzner (or another provider):
*   **Image:** Fresh **Ubuntu 24.04 LTS** (Important! Docker must NOT be pre-installed)
*   **Firewall (Recommended):** Create a firewall in the Hetzner Cloud Panel that only allows ports 22, 80, 443, and ICMP.
    
    *   **Official Guide:** [Hetzner Firewall Docs](https://docs.hetzner.com/robot/dedicated-server/firewall/)
    *   **Configuration (Inbound):**
        The firewall must be configured to **only** allow the following services (everything else is blocked). Enter the rules exactly like this:

        | Name | Protocol | Port | Source IPs |
        | :--- | :--- | :--- | :--- |
        | **SSH** | TCP | `22` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **HTTP** | TCP | `80` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **HTTPS** | TCP | `443` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **ICMP** | ICMP | - | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |

    > **What happens here?**<br>
    > You are renting the "computer" (server) in the data center. With the firewall, you ensure that almost all doors are locked from the outside initially, except for the ones we really need.

### Step 2: Login to Server & Clone Repository

First, connect to your new server.

**🖥️ Mac / Linux / Windows (PowerShell/CMD):**
Open your terminal and enter the following (replace `1.2.3.4` with your server's IP):
```bash
ssh root@1.2.3.4
```
*(Confirm the fingerprint with `yes` and enter the root password you received from Hetzner via email)*

**🪟 Windows (PuTTY Alternative):**
1.  Open PuTTY.
2.  Enter your server's IP address in "Host Name".
3.  Click "Open".
4.  Log in as `root`.

Once logged in, clone this repo:

```bash
apt-get update && apt-get install -y git make
git clone https://github.com/ghiemer/secure-docker-server.git
cd secure-docker-server
```

> **What happens here?**<br>
> You download the construction kit (this repository) to your new server and navigate to the folder. You also install the tools (`git`, `make`) needed to build it.

### Step 3: Start Setup
Start the script. It will guide you interactively through the process.

```bash
chmod +x start.sh
./start.sh
```

You will be asked for:
1.  A new username (e.g., `admin`).
2.  Your **SSH Public Key**.

> **What happens here?**<br>
> This is the main part. The script secures the server: It builds walls (firewall), encrypts storage (swap), and sets up Docker. It asks for your new username so we can disable the insecure "root" user later.

> ⚠️ **IMPORTANT:** During setup, you will be prompted to test the new access in a second terminal. Make sure to do this before the script proceeds!

### Step 4: Reboot & Gateway
After successful completion:
1.  Restart server: `reboot`
2.  Login with new user.
3.  Install your web gateway.

> **What happens here?**<br>
> Restarting activates all security measures (e.g., the new kernel and encrypted hard drive). Then you log in with your new, secure user and can start installing your actual applications.

---

## 🛠️ Manual Installation
Do you want to perform every step yourself instead of using the script?
👉 **[Click here for the step-by-step guide](DOCS/MANUAL_SETUP.md)**

## 🛠️ Troubleshooting

If something goes wrong:
*   The script stops immediately and shows `🚨 ERROR`.
*   Check the logfile: `cat install_TIMESTAMP.log`
*   Passwords and keys are masked with `*****` in the log.

## ⚠️ Warnings
*   IPv6 is **disabled** on this server for security reasons.
*   Root login and password login are **disabled**.

## 📄 License
MIT
