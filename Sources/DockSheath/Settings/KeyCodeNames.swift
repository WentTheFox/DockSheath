import AppKit
import JSON5Config

/// Maps the standard ANSI-layout virtual keycodes (the same numeric space
/// `NSEvent.keyCode` and Carbon's `RegisterEventHotKey` both use — see
/// `GlobalHotKey`) to a short display label, for showing a saved
/// `HotKeyBinding` in the Settings UI without a live `NSEvent` to read
/// `charactersIgnoringModifiers` from. Deliberately not exhaustive — covers
/// the keys someone would plausibly pick for a global shortcut.
enum KeyCodeNames {
    private static let labels: [UInt32: String] = [
        0x00: "A", 0x0B: "B", 0x08: "C", 0x02: "D", 0x0E: "E", 0x03: "F",
        0x05: "G", 0x04: "H", 0x22: "I", 0x26: "J", 0x28: "K", 0x25: "L",
        0x2E: "M", 0x2D: "N", 0x1F: "O", 0x23: "P", 0x0C: "Q", 0x0F: "R",
        0x01: "S", 0x11: "T", 0x20: "U", 0x09: "V", 0x0D: "W", 0x07: "X",
        0x10: "Y", 0x06: "Z",
        0x1D: "0", 0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4",
        0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9",
        0x31: "Space", 0x24: "Return", 0x30: "Tab", 0x33: "Delete",
        0x35: "Escape",
        0x7B: "\u{2190}", 0x7C: "\u{2192}", 0x7D: "\u{2193}", 0x7E: "\u{2191}",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x1B: "-", 0x18: "=", 0x21: "[", 0x1E: "]", 0x2A: "\\",
        0x29: ";", 0x27: "'", 0x2B: ",", 0x2F: ".", 0x2C: "/", 0x32: "`",
    ]

    static func label(for keyCode: UInt32) -> String {
        labels[keyCode] ?? "Key \(keyCode)"
    }

    /// Apple's conventional modifier ordering (⌃⌥⇧⌘) and symbols, used both
    /// for displaying a saved binding and while actively recording one.
    static func modifierSymbols(_ modifiers: [String]) -> String {
        let lowered = Set(modifiers.map { $0.lowercased() })
        var result = ""
        if lowered.contains("control") || lowered.contains("ctrl") { result += "\u{2303}" }
        if lowered.contains("option") || lowered.contains("alt") { result += "\u{2325}" }
        if lowered.contains("shift") { result += "\u{21E7}" }
        if lowered.contains("command") || lowered.contains("cmd") { result += "\u{2318}" }
        return result
    }

    static func displayString(for binding: HotKeyBinding) -> String {
        modifierSymbols(binding.modifiers) + label(for: binding.keyCode)
    }
}
