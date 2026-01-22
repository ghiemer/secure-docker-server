# Infrastruktur & Setup-Flow

Dieses Dokument beschreibt den automatisierten Prozess, mit dem ein Standard-Server in eine sichere Docker-Umgebung verwandelt wird. Der gesamte Prozess wird über ein `Makefile` gesteuert und ist in logische Schritte unterteilt.

## Visualisierung des Setup-Prozesses

Das folgende Diagramm zeigt den Ablauf des Setup-Skripts von Anfang bis Ende.

> Es wird ein Extention benötigt um das Diagram anzuzeigen:
> [https://open-vsx.org/vscode/item?itemName=bierner.markdown-mermaid]. 

```mermaid
graph TD
    A[Start: ./start.sh] --> B{Makefile: install};
    B --> C[0. Preflight Checks];
    C --> D[1. System-Update & Tools];
    D --> E[2. Swap-Konfiguration];
    E --> F[3. User & SSH Setup];
    F --> G[4. System-Härtung];
    G --> H[5. Docker Hardening];
    H --> I[6. Watchdog Service];
    I --> J[7. Finale Verifizierung];
    J --> K[Ende: Server bereit];

    subgraph "Details: Phase 4 Härtung"
        G --> G_1[Kernel-Parameter];
        G --> G_2["Firewall (UFW)"];
        G --> G_3[Fail2Ban];
        G --> G_4[Auditd];
    end

    subgraph "Details: Phase 7 Verifizierung"
        J --> J_1[Check: User];
        J --> J_2[Check: SSH];
        J --> J_3[Check: Firewall];
        J --> J_4[Check: Docker];
    end
```

## Erklärung der Komponenten

Jeder Schritt im Diagramm hat einen spezifischen Zweck, um die Sicherheit und Stabilität des Servers zu gewährleisten.

| Phase | Komponente | Zweck |
| :--- | :--- | :--- |
| **0. Preflight** | `00-preflight.sh` | Stellt sicher, dass das Skript unter den richtigen Bedingungen (Root-Rechte, Ubuntu 24.04) ausgeführt wird, bevor Änderungen vorgenommen werden. |
| **1. System** | `01-system.sh` | Bringt das Betriebssystem auf den neuesten Stand und installiert alle notwendigen Werkzeuge für die weiteren Schritte (Firewall, Verschlüsselung, etc.). |
| **2. Swap** | `02-swap.sh` | Konfiguriert den Swap-Speicher. Bei wenig RAM wird ein **verschlüsselter** Swap erstellt, um sensible Daten zu schützen. Bei viel RAM wird er aus Sicherheitsgründen deaktiviert. |
| **3. User & SSH** | `03-user-safe.sh` | Erstellt einen neuen, unprivilegierten Benutzer für die tägliche Arbeit und sichert den SSH-Zugang ab. Der "Anti-Lockout"-Mechanismus verhindert, dass man sich versehentlich selbst aussperrt. |
| **4. Härtung** | `Makefile (harden)` | Dies ist das Herzstück der Härtung. Es aktiviert die Firewall, schützt vor Brute-Force-Angriffen, optimiert den Kernel und aktiviert automatische Sicherheitsupdates. |
| **5. Docker** | `04-docker.sh` | Installiert die Docker Engine und wendet eine gehärtete Konfiguration an, um die Angriffsfläche zu minimieren. |
| **6. Watchdog**| `Makefile (watchdog)` | Installiert einen Überwachungsdienst, der regelmäßig prüft, ob versehentlich unsichere Ports geöffnet wurden. |
| **7. Verifizierung**| `99-verify.sh`| Ein abschließender Audit, der prüft, ob alle vorherigen Schritte erfolgreich waren und der Server dem gewünschten Sicherheitsstandard entspricht. |
