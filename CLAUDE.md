# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
# Compile
swiftc main.swift -o flipotron -framework Carbon -framework AppKit

# Deploy to app bundle
cp flipotron /Applications/Flipotron.app/Contents/MacOS/flipotron

# Restart service
launchctl bootout gui/$(id -u)/com.pavelbrick.flipotron 2>/dev/null
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pavelbrick.flipotron.plist

# Check logs
cat /tmp/flipotron.log
```

Full install from scratch: `./install.sh`

## Architecture

Single-file Swift app (`main.swift`, ~550 LOC) with no dependencies beyond system frameworks (Carbon, AppKit).

**Two conversion modes:**
1. **Keycode retype** (primary) — for text just typed. Records keystrokes into buffer, on trigger: delete×N → toggle layout → replay same keycodes. Never touches clipboard.
2. **Clipboard-based** (fallback) — for selected text or when buffer is empty. Cmd+C → dictionary convert → Cmd+V → restore original clipboard.

**Key state variables:**
- `keystrokeBuffer: [KeyStroke]` — current word being typed
- `previousWordBuffer: [KeyStroke]` — word before last space (allows converting previous word)
- `switching: Bool` — blocks event tap from processing synthetic events during conversion
- `justConverted: Bool` — enables undo on repeated Right Option press

**Event flow:** `CGEvent.tapCreate` → `eventTapCallback` → records keystrokes or triggers conversion → `convertBufferAndRetype` / `convertSelectedText` — all async via `DispatchQueue.main.asyncAfter` with small delays for macOS input processing.

**Layout IDs are hardcoded:** `com.apple.keylayout.ABC` and `com.apple.keylayout.RussianWin`.
