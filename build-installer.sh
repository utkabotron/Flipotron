#!/bin/bash
set -e

APP_NAME="Flipotron"
BUNDLE_ID="com.pavelbrick.flipotron"
VERSION="1.0.0"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
PKG_OUTPUT="$SCRIPT_DIR/$APP_NAME-Installer.pkg"

echo "=== Сборка установщика $APP_NAME ==="
echo ""

# ── Проверка окружения ──────────────────────────────────

if ! command -v swiftc &>/dev/null; then
    echo "Ошибка: не найден компилятор Swift."
    echo "Установите Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

if ! command -v pkgbuild &>/dev/null; then
    echo "Ошибка: не найден pkgbuild. Запустите этот скрипт на macOS."
    exit 1
fi

# ── Очистка ─────────────────────────────────────────────

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# ── Сборка бинарника ────────────────────────────────────

echo "[1/4] Компиляция..."
swiftc "$SCRIPT_DIR/main.swift" -o "$BUILD_DIR/flipotron" \
    -framework Carbon -framework AppKit -O
echo "      Готово."

# ── Создание .app бандла ────────────────────────────────

echo "[2/4] Создание $APP_NAME.app..."

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/flipotron" "$APP_BUNDLE/Contents/MacOS/"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleExecutable</key>
    <string>flipotron</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
PLIST

echo "      Готово."

# ── Postinstall скрипт (автозапуск) ─────────────────────

echo "[3/4] Подготовка установочных скриптов..."

SCRIPTS_DIR="$BUILD_DIR/scripts"
mkdir -p "$SCRIPTS_DIR"

cat > "$SCRIPTS_DIR/postinstall" <<'SCRIPT'
#!/bin/bash
# Настройка автозапуска для текущего пользователя
CURRENT_USER=$(stat -f "%Su" /dev/console)
CURRENT_UID=$(id -u "$CURRENT_USER")
PLIST_DIR="/Users/$CURRENT_USER/Library/LaunchAgents"
PLIST_FILE="$PLIST_DIR/com.pavelbrick.flipotron.plist"

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

chown "$CURRENT_USER" "$PLIST_FILE"

# Загрузить LaunchAgent и запустить приложение
sudo -u "$CURRENT_USER" launchctl bootstrap "gui/$CURRENT_UID" "$PLIST_FILE" 2>/dev/null || true
sudo -u "$CURRENT_USER" open /Applications/Flipotron.app 2>/dev/null || true

exit 0
SCRIPT

chmod +x "$SCRIPTS_DIR/postinstall"
echo "      Готово."

# ── Сборка .pkg ─────────────────────────────────────────

echo "[4/4] Сборка .pkg инсталлятора..."

pkgbuild \
    --root "$APP_BUNDLE" \
    --install-location "/Applications/$APP_NAME.app" \
    --identifier "$BUNDLE_ID" \
    --version "$VERSION" \
    --scripts "$SCRIPTS_DIR" \
    "$PKG_OUTPUT"

echo "      Готово."

# ── Очистка ─────────────────────────────────────────────

rm -rf "$BUILD_DIR"

echo ""
echo "=== Инсталлятор готов! ==="
echo ""
echo "  $PKG_OUTPUT"
echo ""
echo "Отправьте этот файл другу — он кликнет дважды,"
echo "macOS проведёт через установку, и Flipotron появится"
echo "в /Applications с автозапуском."
