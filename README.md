# Flipotron

A macOS menu bar app that fixes text typed in the wrong keyboard layout (QWERTY ↔ ЙЦУКЕН).

No clipboard involved for regular typing — Flipotron deletes and retypes your text with correct keycodes after switching the layout.

## The Problem

You're typing and realize the whole word came out as `ghbdtn` instead of `привет` (or vice versa). You'd have to delete it, switch layout, and retype manually.

## How It Works

**Right Option** — converts the last word you typed:

```
Type:  ghbdtn
Press: Right Option
Get:   привет
```

It also works in reverse:

```
Type:  привет    (while in Russian layout, but meant to type English)
Press: Right Option
Get:   privet
```

**Right Option after Space** — converts the *previous* word:

```
Type:  ghbdtn [space] ...
Press: Right Option
Get:   привет [space] ...
```

**Right Option with no buffer** — converts selected text (clipboard-based), or toggles the layout if nothing is selected.

**Right Option again** (without typing anything new) — undo the conversion.

**Alt+A** — toggle case of selected text (`hello` ↔ `HELLO`, `привет` ↔ `ПРИВЕТ`).

## Menu Bar Icon

The icon flips vertically to indicate the current layout:

- Normal — English (ABC)
- Flipped — Russian (ЙЦУКЕН)

## Installation

### Prerequisites

- macOS
- Accessibility permissions (the app will prompt on first launch)

### Build from source

```bash
cd Flipotron
swiftc main.swift -o layout-switcher -framework Carbon -framework AppKit
```

### Deploy

Create an app bundle and copy the binary:

```bash
mkdir -p /Applications/Flipotron.app/Contents/MacOS
cp layout-switcher /Applications/Flipotron.app/Contents/MacOS/
```

### Autostart (optional)

Create `~/Library/LaunchAgents/com.pavelbrick.flipotron.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pavelbrick.flipotron</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Applications/Flipotron.app/Contents/MacOS/layout-switcher</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Then load it:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.pavelbrick.flipotron.plist
```

## How It Works Under the Hood

1. An event tap listens for all keystrokes and records keycodes into a buffer
2. On **Right Option**, Flipotron sends Delete keys to erase the word, toggles the input source via `TISSelectInputSource`, then replays the same keycodes — producing the correct characters in the new layout
3. For selected text (when the buffer is empty), it falls back to clipboard-based conversion using a character mapping dictionary
4. Mouse clicks and navigation keys clear the buffer

## License

MIT
