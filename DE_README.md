# 🛡️ Secure Docker Server Setup (Hetzner Edition)

> 🇺🇸 **[English Version](README.md)**
>
> 🛠️ **[Manuelle Installations-Anleitung](DOCS/DE_MANUAL_SETUP.md)**

Dieses Repository verwandelt einen frischen Ubuntu 24.04 Server in eine **gehärtete Festung** für Docker-Anwendungen. Es automatisiert Best Practices für Sicherheit, Firewalling und System-Konfiguration.

## 🎯 Features

*   ✅ **OS Hardening:** Sysctl Tweaks, Auditd, Secure Swap (verschlüsselt).
*   ✅ **SSH Safe-Lock:** Interaktive Einrichtung von SSH-Keys mit "Anti-Aussperr-Garantie".
*   ✅ **Firewall:** UFW vorkonfiguriert (nur 22, 80, 443).
*   ✅ **Docker Security:** Daemon Hardening, No-New-Privileges, Log-Limits.
*   ✅ **Docker Compose:** Installiert automatisch das moderne Docker Compose V2 Plugin (`docker compose`).
*   ✅ **Watchdog:** Überwacht versehentlich geöffnete Ports.
*   ✅ **Logging:** Schreibt ein Logfile (`setup.log`) und maskiert Secrets (*****).

## 📋 Voraussetzungen

Damit die Installation reibungslos durchläuft, müssen folgende Bedingungen erfüllt sein:

*   **OS:** Ein frisches **Ubuntu 24.04 LTS** (empfohlen).
*   **User:** Root-Zugriff (via SSH).
*   **Tools:** `git` und `make` werden für das Setup benötigt.
    
    Installation:
    ```bash
    apt-get update && apt-get install -y git make
    ```
*   **Docker:** Muss **NICHT** vorinstalliert sein (das Skript erledigt das sauber und sicher für dich).

## 🚀 Installation

### Schritt 1: Server erstellen

> # 🎁 20€ HETZNER STARTGUTHABEN GESCHENKT
>
> Nutze diesen Link für die Registrierung, um **sofort 20€ Guthaben** für alle Cloud-Produkte zu erhalten:
>
> 👉 **[https://hetzner.cloud/?ref=6uP8iWBs6GUZ](https://hetzner.cloud/?ref=6uP8iWBs6GUZ)**
>
> **Dein Vorteil:** 20€ geschenkt zum Start.
> **Unser Support:** Sobald du 10€ investierst, erhalten wir als Dankeschön 10€ für dieses Projekt. **Win-Win!** 🤝

Erstelle dann einen Server bei Hetzner (oder einem anderen Provider):
*   **Image:** Ubuntu 24.04 LTS
*   **Firewall (Empfohlen):** Im Hetzner Cloud Panel eine Firewall erstellen.
    
    *   **Offizielle Anleitung:** [Hetzner Firewall Docs](https://docs.hetzner.com/de/robot/dedicated-server/firewall/)
    *   **Konfiguration (Eingehend):**
        Die Firewall muss so konfiguriert werden, dass sie **nur** folgende Dienste durchlässt (alles andere wird blockiert). Trage die Regeln exakt so ein:

        | Name | Protokoll | Port | Quell-IPs |
        | :--- | :--- | :--- | :--- |
        | **SSH** | TCP | `22` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **HTTP** | TCP | `80` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **HTTPS** | TCP | `443` | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |
        | **ICMP** | ICMP | - | `0.0.0.0/0`, `::/0` (Any IPv4/IPv6) |

    > **Was passiert hier?**<br>
    > Du mietest dir den "Computer" (Server) im Rechenzentrum. Mit der Firewall sorgst du dafür, dass von außen erstmal fast alle Türen verschlossen sind, außer die, die wir wirklich brauchen.

### Schritt 2: Auf dem Server einloggen & Repository klonen

Verbinde dich zunächst mit deinem neuen Server.

**🖥️ Mac / Linux / Windows (PowerShell/CMD):**
Öffne das Terminal und gib Folgendes ein (ersetze `1.2.3.4` durch die IP deines Servers):
```bash
ssh root@1.2.3.4
```
*(Bestätige den Fingerprint mit `yes` und gib das Root-Passwort ein, das du von Hetzner per Mail bekommen hast)*

**🪟 Windows (PuTTY Alternative):**
1.  Öffne PuTTY.
2.  Trage bei "Host Name" die IP-Adresse deines Servers ein.
3.  Klicke auf "Open".
4.  Logge dich als `root` ein.

Sobald du eingeloggt bist, klone dieses Repo:

```bash
apt-get update && apt-get install -y git make
git clone https://github.com/DEIN-USER/secure-docker-server.git
cd secure-docker-server
```

> **Was passiert hier?**<br>
> Du lädst den Baukasten (dieses Repository) auf deinen neuen Server herunter und gehst in den entsprechenden Ordner. Außerdem installierst du die Werkzeuge (`git`, `make`), die wir zum Aufbauen brauchen.

### Schritt 3: Setup starten
Starte das Skript. Es führt dich interaktiv durch den Prozess.

```bash
chmod +x start.sh
./start.sh
```

Du wirst gefragt nach:
1.  Einem neuen Benutzernamen (z.B. `admin`).
2.  Deinem **SSH Public Key**.

> **Was passiert hier?**<br>
> Das ist der Hauptteil. Das Skript sichert den Server ab: Es baut Mauern (Firewall), verschlüsselt den Speicher (Swap) und richtet Docker ein. Es fragt dich nach deinem neuen Benutzernamen, damit wir den unsicheren "Root"-Benutzer später abschalten können.

Du wirst gefragt nach:
1.  Einem neuen Benutzernamen (z.B. `admin`).
2.  Deinem **SSH Public Key**.

> ⚠️ **WICHTIG:** Während des Setups wirst du aufgefordert, den neuen Zugang in einem zweiten Terminal zu testen. Tue dies unbedingt, bevor das Skript weitermacht!

### Schritt 4: Reboot & Gateway
Nach erfolgreichem Durchlauf:
1.  Server neustarten: `reboot`
2.  Mit neuem User einloggen.
3.  Dein Web-Gateway installieren.

> **Was passiert hier?**<br>
> Durch den Neustart werden alle Sicherheitsmaßnahmen aktiv (z.B. der neue Kernel und die verschlüsselte Festplatte). Danach loggst du dich mit deinem neuen, sicheren Benutzer ein und kannst anfangen, deine eigentlichen Anwendungen zu installieren.

---

## 🛠️ Manuelle Installation
Möchtest du statt dem Skript jeden Schritt selbst durchführen?
👉 **[Hier geht es zur Schritt-für-Schritt Anleitung](DOCS/DE_MANUAL_SETUP.md)**

## 🛠️ Fehlerbehebung

Wenn etwas schiefgeht:
*   Das Skript stoppt sofort und zeigt `🚨 ERROR`.
*   Prüfe die Logdatei: `cat install_TIMESTAMP.log`
*   Passwörter und Keys sind im Log mit `*****` maskiert.

## ⚠️ Warnungen
*   IPv6 wird auf diesem Server aus Sicherheitsgründen **deaktiviert**.
*   Root-Login und Passwort-Login werden **deaktiviert**.

## 📄 Lizenz
MIT
