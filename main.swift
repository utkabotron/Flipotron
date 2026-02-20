import Carbon
import AppKit

// MARK: - Conversion tables EN↔RU (QWERTY ↔ ЙЦУКЕН)

let enToRu: [Character: Character] = [
    "q": "й", "w": "ц", "e": "у", "r": "к", "t": "е", "y": "н", "u": "г", "i": "ш", "o": "щ", "p": "з",
    "[": "х", "]": "ъ",
    "a": "ф", "s": "ы", "d": "в", "f": "а", "g": "п", "h": "р", "j": "о", "k": "л", "l": "д",
    ";": "ж", "'": "э",
    "z": "я", "x": "ч", "c": "с", "v": "м", "b": "и", "n": "т", "m": "ь",
    ",": "б", ".": "ю",
]

let ruToEn: [Character: Character] = {
    var d: [Character: Character] = [:]
    for (en, ru) in enToRu { d[ru] = en }
    return d
}()

// MARK: - Cyrillic helpers

func isCyrillicUpper(_ ch: Character) -> Bool {
    guard let scalar = ch.unicodeScalars.first else { return false }
    return scalar.value >= 0x0410 && scalar.value <= 0x042F
}

func cyrillicLower(_ ch: Character) -> Character {
    guard let scalar = ch.unicodeScalars.first else { return ch }
    if scalar.value >= 0x0410 && scalar.value <= 0x042F {
        return Character(UnicodeScalar(scalar.value + 0x20)!)
    }
    return ch
}

func cyrillicUpper(_ ch: Character) -> Character {
    guard let scalar = ch.unicodeScalars.first else { return ch }
    if scalar.value >= 0x0430 && scalar.value <= 0x044F {
        return Character(UnicodeScalar(scalar.value - 0x20)!)
    }
    return ch
}

// MARK: - KeyStroke

struct KeyStroke {
    let keyCode: UInt16
    let shift: Bool
}

// MARK: - Menu bar icon

var globalStatusItem: NSStatusItem?
var iconNormal: NSImage?
var iconFlipped: NSImage?

func createFlippedImage(_ source: NSImage) -> NSImage {
    let size = source.size
    let flipped = NSImage(size: size)
    flipped.lockFocus()
    let transform = NSAffineTransform()
    transform.translateX(by: 0, yBy: size.height)
    transform.scaleX(by: 1, yBy: -1)
    transform.concat()
    source.draw(in: NSRect(origin: .zero, size: size))
    flipped.unlockFocus()
    flipped.isTemplate = true
    return flipped
}

func updateMenuBarIcon() {
    let icon = isCurrentLayoutEN() ? iconNormal : iconFlipped
    globalStatusItem?.button?.image = icon
}

// MARK: - State

var keystrokeBuffer: [KeyStroke] = []
var previousWordBuffer: [KeyStroke] = []
var lastBoundaryKeyStroke: KeyStroke? = nil
var switching = false
var justConverted = false

// Space saves current buffer to previousWordBuffer
let saveWordBoundaryKeyCodes: Set<UInt16> = [
    49,  // Space
]

// These clear all buffers
let clearBufferKeyCodes: Set<UInt16> = [
    36,  // Return
    48,  // Tab
    123, // Left
    124, // Right
    125, // Down
    126, // Up
    115, // Home
    119, // End
]

// MARK: - Layout switching

func getCurrentInputSourceID() -> String? {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
    guard let ptr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { return nil }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}

func switchToLayout(_ layoutID: String) {
    let criteria = [kTISPropertyInputSourceID as String: layoutID] as CFDictionary
    guard let list = TISCreateInputSourceList(criteria, false)?.takeRetainedValue() as? [TISInputSource],
          let source = list.first else {
        print("Layout not found: \(layoutID)")
        return
    }
    TISSelectInputSource(source)
}

let abcID = "com.apple.keylayout.ABC"
let russianID = "com.apple.keylayout.RussianWin"

func isCurrentLayoutEN() -> Bool {
    let current = getCurrentInputSourceID() ?? ""
    return current.contains("ABC")
}

func toggleLayout() {
    if isCurrentLayoutEN() {
        switchToLayout(russianID)
    } else {
        switchToLayout(abcID)
    }
    updateMenuBarIcon()
}

// MARK: - Synthetic key events

func postDeleteKeys(count: Int) {
    let src = CGEventSource(stateID: .hidSystemState)
    for _ in 0..<count {
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x33, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

func postKeyStrokes(_ keystrokes: [KeyStroke]) {
    let src = CGEventSource(stateID: .hidSystemState)
    for ks in keystrokes {
        let down = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: ks.keyCode, keyDown: false)
        if ks.shift {
            down?.flags = .maskShift
            up?.flags = .maskShift
        }
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

func postCmdC() {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)
    let up = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
    down?.flags = .maskCommand
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

func postCmdV() {
    let src = CGEventSource(stateID: .hidSystemState)
    let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
    let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
    down?.flags = .maskCommand
    up?.flags = .maskCommand
    down?.post(tap: .cghidEventTap)
    up?.post(tap: .cghidEventTap)
}

// MARK: - Convert buffer via keycode retype (no clipboard)

func convertBufferAndRetype(_ buffer: [KeyStroke], extraDeleteCount: Int = 0) {
    guard !buffer.isEmpty else { return }

    let deleteCount = buffer.count + extraDeleteCount
    switching = true

    postDeleteKeys(count: deleteCount)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
        toggleLayout()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
            postKeyStrokes(buffer)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                keystrokeBuffer = buffer
                previousWordBuffer = []
                lastBoundaryKeyStroke = nil
                justConverted = true
                switching = false
                updateMenuBarIcon()
            }
        }
    }
}

// MARK: - Convert selected text via clipboard + dictionary

func convertSelectedText() {
    switching = true

    let savedClipboard = NSPasteboard.general.string(forType: .string)
    let savedChangeCount = NSPasteboard.general.changeCount

    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("", forType: .string)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        postCmdC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newChangeCount = NSPasteboard.general.changeCount
            guard newChangeCount != savedChangeCount,
                  let selectedText = NSPasteboard.general.string(forType: .string),
                  !selectedText.isEmpty else {
                // No selection — just toggle layout
                toggleLayout()
                // Restore clipboard
                if let saved = savedClipboard {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(saved, forType: .string)
                }
                switching = false
                updateMenuBarIcon()
                return
            }

            // Determine direction from first character
            let firstChar = selectedText.first!
            let isEN = firstChar.asciiValue != nil && firstChar.asciiValue! < 128

            var converted: [Character] = []
            for ch in selectedText {
                var result: Character?
                if isEN {
                    let lower = Character(ch.lowercased())
                    result = enToRu[lower]
                    if let r = result, ch != lower {
                        result = cyrillicUpper(r)
                    }
                } else {
                    let isUpper = isCyrillicUpper(ch)
                    let lower = cyrillicLower(ch)
                    result = ruToEn[lower]
                    if let r = result, isUpper {
                        result = Character(r.uppercased())
                    }
                }
                converted.append(result ?? ch)
            }

            let convertedStr = String(converted)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(convertedStr, forType: .string)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                postCmdV()
                toggleLayout()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    justConverted = false
                    switching = false
                    updateMenuBarIcon()

                    // Restore clipboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let saved = savedClipboard {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(saved, forType: .string)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Toggle case of selected text (Alt+A)

func toggleSelectedCase() {
    switching = true

    let savedClipboard = NSPasteboard.general.string(forType: .string)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
        postCmdC()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let selectedText = NSPasteboard.general.string(forType: .string),
                  !selectedText.isEmpty else {
                switching = false
                return
            }

            var toggled: [Character] = []
            for ch in selectedText {
                if ch.isUppercase {
                    toggled.append(contentsOf: ch.lowercased())
                } else if ch.isLowercase {
                    toggled.append(contentsOf: ch.uppercased())
                } else if isCyrillicUpper(ch) {
                    toggled.append(cyrillicLower(ch))
                } else {
                    let upper = cyrillicUpper(ch)
                    if upper != ch {
                        toggled.append(upper)
                    } else {
                        toggled.append(ch)
                    }
                }
            }

            let toggledStr = String(toggled)
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(toggledStr, forType: .string)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                postCmdV()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    switching = false

                    // Restore clipboard
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        if let saved = savedClipboard {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(saved, forType: .string)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Event tap callback

var globalTap: CFMachPort?
var rightAltDown = false

func eventTapCallback(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {

    // Re-enable tap if disabled by system
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = globalTap {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        return Unmanaged.passUnretained(event)
    }

    if switching {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags

    // Mouse down — clear buffer
    if type == .leftMouseDown || type == .rightMouseDown {
        keystrokeBuffer = []
        previousWordBuffer = []
        lastBoundaryKeyStroke = nil
        justConverted = false
        return Unmanaged.passUnretained(event)
    }

    // keyDown
    if type == .keyDown {
        // Alt+A (keyCode 0 = 'a') — toggle case
        if keyCode == 0 && flags.contains(.maskAlternate) {
            DispatchQueue.main.async {
                toggleSelectedCase()
            }
            return nil // consume the event
        }

        // Cmd or Ctrl held — clear buffer
        if flags.contains(.maskCommand) || flags.contains(.maskControl) {
            keystrokeBuffer = []
            previousWordBuffer = []
            lastBoundaryKeyStroke = nil
            justConverted = false
            return Unmanaged.passUnretained(event)
        }

        // Backspace (keyCode 51)
        if keyCode == 51 {
            if !keystrokeBuffer.isEmpty {
                keystrokeBuffer.removeLast()
            }
            justConverted = false
            return Unmanaged.passUnretained(event)
        }

        // Space — save current buffer as previous word
        if saveWordBoundaryKeyCodes.contains(keyCode) {
            if !keystrokeBuffer.isEmpty {
                previousWordBuffer = keystrokeBuffer
                lastBoundaryKeyStroke = KeyStroke(keyCode: keyCode, shift: flags.contains(.maskShift))
            }
            keystrokeBuffer = []
            justConverted = false
            return Unmanaged.passUnretained(event)
        }

        // Arrow keys / Home / End — clear everything
        if clearBufferKeyCodes.contains(keyCode) {
            keystrokeBuffer = []
            previousWordBuffer = []
            lastBoundaryKeyStroke = nil
            justConverted = false
            return Unmanaged.passUnretained(event)
        }

        // Regular key — record keystroke
        if justConverted {
            keystrokeBuffer = []
            previousWordBuffer = []
            lastBoundaryKeyStroke = nil
            justConverted = false
        }

        let shift = flags.contains(.maskShift)
        keystrokeBuffer.append(KeyStroke(keyCode: keyCode, shift: shift))

        return Unmanaged.passUnretained(event)
    }

    // flagsChanged — Right Option (keyCode 61)
    if type == .flagsChanged && keyCode == 61 {
        if flags.contains(.maskAlternate) {
            // Key down
            rightAltDown = true
        } else if rightAltDown {
            // Key up
            rightAltDown = false

            if !keystrokeBuffer.isEmpty {
                // Mode 1: convert current word buffer via keycode retype
                let snapshot = keystrokeBuffer
                keystrokeBuffer = []
                DispatchQueue.main.async {
                    convertBufferAndRetype(snapshot)
                }
            } else if !previousWordBuffer.isEmpty {
                // Mode 1b: convert previous word (after boundary like space)
                let snapshot = previousWordBuffer
                let extraDelete = lastBoundaryKeyStroke != nil ? 1 : 0
                previousWordBuffer = []
                lastBoundaryKeyStroke = nil
                DispatchQueue.main.async {
                    convertBufferAndRetype(snapshot, extraDeleteCount: extraDelete)
                }
            } else {
                // Mode 2/3: try selected text, fallback to toggle
                DispatchQueue.main.async {
                    convertSelectedText()
                }
            }
        }
        return Unmanaged.passUnretained(event)
    }

    return Unmanaged.passUnretained(event)
}

// MARK: - App Delegate with menu bar icon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        globalStatusItem = statusItem

        let iconBase64 = "iVBORw0KGgoAAAANSUhEUgAAACQAAAAkCAYAAADhAJiYAAABnUlEQVR4AeyW3W2DMBDHS5UB6KMlQMkGGaXdoCMkE5RMkG7QEdpN2g0SARKPzQBI7v8eLkLY+GwQaSsZcfLh+/rpsA33d3/sikDSC/k/Haqq6rGu63IJodxjnbJ2CBA6SZJ3BL0sIZSbaiC3cRtALnojeuaErZYBBPrtlDp5nie+wvlttQwgdv6tMQJJnY8dih2SOiDZ4xq6SYfohB77NkkAQ/vsV7ZarTacFFDfrE8dZwERjFLq3CueAuqz9xyszgE6DGC4+LZpmiM/hI6TgPCVfsW6KceKaa13+LV4HrO75oOBAHPOsmzvSko2+L21bbsmPURCgS6AuS5iqVDXdSdcqeTXtwcB4TU99IN9dCz8oJ3nDQSYxAfA5oOdp23ztjkvILQ+uDPDYoDy6pQIhJZvcF2GBSY8pzgOTlKcEwg7Za+U6p98Uj6nHcfBGlDOM8oAQtAXZ4V+RKu1j3CMNCLnjn2gX2vxnAFUFMUHG5cebbUMIIKgHQX6J+iHJYRyUw3kNm4rEHkRPYLKJYRyUw2bjALZnG8xF4GkLv8AAAD//5UqXQoAAAAGSURBVAMA4mgFWJQXVcYAAAAASUVORK5CYII="
        if let iconData = Data(base64Encoded: iconBase64),
           let image = NSImage(data: iconData) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            iconNormal = image
            iconFlipped = createFlippedImage(image)
        }

        updateMenuBarIcon()

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Flipotron", action: nil, keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu

        // Check accessibility permissions
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("⚠️  Accessibility access required.")
        }

        // Create event tap
        let eventMask = (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.leftMouseDown.rawValue)
            | (1 << CGEventType.rightMouseDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: eventTapCallback,
            userInfo: nil
        ) else {
            print("❌ Failed to create event tap.")
            NSApp.terminate(nil)
            return
        }

        globalTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("✅ Flipotron running.")
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Main

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
