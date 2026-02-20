#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="/Applications/Flipotron.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
PLIST_DIR="$APP_DIR/Contents"
BINARY="$MACOS_DIR/flipotron"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.pavelbrick.flipotron.plist"
SERVICE_LABEL="com.pavelbrick.flipotron"

echo "🔧 Flipotron Installer"
echo "======================"

# 1. Check swiftc
if ! command -v swiftc &>/dev/null; then
    echo "❌ swiftc not found. Install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi
echo "✅ swiftc found"

# 2. Compile
echo "⏳ Compiling main.swift..."
swiftc "$SCRIPT_DIR/main.swift" -o "$SCRIPT_DIR/flipotron" -framework Carbon -framework AppKit
echo "✅ Compiled"

# 3. Create .app bundle
echo "⏳ Creating Flipotron.app..."
mkdir -p "$MACOS_DIR"
cp "$SCRIPT_DIR/flipotron" "$BINARY"

# 4. Generate Info.plist
cat > "$PLIST_DIR/Info.plist" << 'INFOPLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.pavelbrick.layoutswitcher</string>
    <key>CFBundleName</key>
    <string>Flipotron</string>
    <key>CFBundleExecutable</key>
    <string>flipotron</string>
    <key>CFBundleVersion</key>
    <string>2.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
INFOPLIST
echo "✅ App bundle created"

# 5. Ad-hoc code sign
echo "⏳ Signing..."
codesign --force --deep --sign - "$APP_DIR"
echo "✅ Signed"

# 6. Create LaunchAgent
echo "⏳ Setting up LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$LAUNCH_AGENT" << LAUNCHPLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${SERVICE_LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>${BINARY}</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/flipotron.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/flipotron.log</string>
</dict>
</plist>
LAUNCHPLIST
echo "✅ LaunchAgent created"

# 7. Start service
echo "⏳ Starting Flipotron..."
launchctl bootout "gui/$(id -u)/$SERVICE_LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENT"
echo "✅ Flipotron started"

# 8. Open Accessibility settings
echo ""
echo "📋 IMPORTANT: Add Flipotron to Accessibility permissions!"
echo "   System Settings will open now."
echo "   Go to: Privacy & Security → Accessibility"
echo "   Click '+' and add /Applications/Flipotron.app"
echo ""
open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

echo "🎉 Done! Check: cat /tmp/flipotron.log"
