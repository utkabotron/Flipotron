#!/bin/bash
set -e

APP_NAME="Flipotron"
APP_DIR="/Applications/${APP_NAME}.app/Contents/MacOS"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.pavelbrick.flipotron.plist"

echo "=== Установка $APP_NAME ==="
echo ""

# Check for Swift compiler
if ! command -v swiftc &>/dev/null; then
    echo "Ошибка: не найден компилятор Swift."
    echo "Установите Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Build
echo "[1/3] Сборка..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
swiftc "$SCRIPT_DIR/main.swift" -o "$SCRIPT_DIR/flipotron" -framework Carbon -framework AppKit
echo "      Готово."

# Deploy
echo "[2/3] Установка в /Applications..."
mkdir -p "$APP_DIR"
cp "$SCRIPT_DIR/flipotron" "$APP_DIR/"
echo "      Готово."

# Autostart
echo "[3/3] Автозапуск..."
mkdir -p "$PLIST_DIR"
cat > "$PLIST_FILE" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pavelbrick.flipotron</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Flipotron.app/Contents/MacOS/flipotron</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
PLIST

launchctl bootstrap gui/$(id -u) "$PLIST_FILE" 2>/dev/null || true
echo "      Готово."

echo ""
echo "=== $APP_NAME установлен! ==="
echo ""
echo "При первом запуске macOS попросит разрешение на Accessibility."
echo "Откройте: Системные настройки → Конфиденциальность → Универсальный доступ"
echo "и добавьте Flipotron в список."
echo ""
echo "Запускаю..."
open "/Applications/${APP_NAME}.app"
