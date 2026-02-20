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

```bash
git clone https://github.com/utkabotron/Flipotron.git
cd Flipotron
./install.sh
```

The script compiles from source, creates an app bundle in `/Applications`, sets up autostart via LaunchAgent, and opens Accessibility settings.

**Requirements:** macOS with Xcode Command Line Tools (`xcode-select --install`).

After install, add `Flipotron.app` to **System Settings → Privacy & Security → Accessibility**.

## Flipotron vs Punto Switcher

| | Flipotron | Punto Switcher |
|---|---|---|
| Conversion | Manual (Right Option) | Auto-detection by dictionary |
| False triggers | None — you decide when to convert | Frequent on short words, code, URLs |
| Clipboard | Not used (keycode retype) | Replaces clipboard content |
| Undo | Right Option again | Breaks on fast typing |
| Privacy | Offline, open source, ~400 LOC | Closed source, Yandex telemetry |
| Weight | Single binary, no dependencies | ~50 MB installer |
| macOS support | Native (Swift + Carbon) | Discontinued since 2021 |
| Price | Free | Was free (now unavailable) |

## How It Works Under the Hood

1. An event tap listens for all keystrokes and records keycodes into a buffer
2. On **Right Option**, Flipotron sends Delete keys to erase the word, toggles the input source via `TISSelectInputSource`, then replays the same keycodes — producing the correct characters in the new layout
3. For selected text (when the buffer is empty), it falls back to clipboard-based conversion using a character mapping dictionary
4. Mouse clicks and navigation keys clear the buffer

## License

MIT
