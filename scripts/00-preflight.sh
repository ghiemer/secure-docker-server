#!/bin/bash
set -e
set -x  # Enable full command tracing for logging

echo "🔍 Checking Environment..."

if [ "$(id -u)" -ne 0 ]; then
    echo "🚨 ERROR: Script must be run as ROOT."
    exit 1
fi

source /etc/os-release
if [[ "$VERSION_ID" != "24."* ]]; then
    echo "⚠️  WARNUNG: Dieses Script ist für Ubuntu 24.04 optimiert."
    echo "   Aktuell: $PRETTY_NAME"
    echo "   Drücke STRG+C zum Abbrechen oder ENTER zum Fortfahren..."
    read
fi

# Internet Check
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    echo "🚨 ERROR: Keine Internetverbindung!"
    exit 1
fi

echo "✅ Pre-flight OK."
