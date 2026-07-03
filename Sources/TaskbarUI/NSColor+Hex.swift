import AppKit

extension NSColor {
    /// Parses `#RGB`, `#RRGGBB`, or `#RRGGBBAA` hex color strings from config
    /// (leading `#` optional). Returns `nil` for anything else so callers can
    /// fall back to a system default instead of failing on a typo.
    public convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        let expanded: String
        switch hex.count {
        case 3:
            expanded = hex.map { "\($0)\($0)" }.joined()
        case 6, 8:
            expanded = hex
        default:
            return nil
        }

        guard let value = UInt32(expanded, radix: 16) else { return nil }

        let hasAlpha = expanded.count == 8
        let r, g, b, a: UInt32
        if hasAlpha {
            r = (value >> 24) & 0xFF
            g = (value >> 16) & 0xFF
            b = (value >> 8) & 0xFF
            a = value & 0xFF
        } else {
            r = (value >> 16) & 0xFF
            g = (value >> 8) & 0xFF
            b = value & 0xFF
            a = 0xFF
        }

        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    /// The inverse of `init(hexString:)` — `"#RRGGBB"`, or `"#RRGGBBAA"` when
    /// the color isn't fully opaque. Used by the Settings UI to persist a
    /// `ColorPicker`'s `Color` back into config as a hex string.
    public var hexString: String {
        let converted = usingColorSpace(.sRGB) ?? self
        let r = Int((converted.redComponent * 255).rounded())
        let g = Int((converted.greenComponent * 255).rounded())
        let b = Int((converted.blueComponent * 255).rounded())
        let a = Int((converted.alphaComponent * 255).rounded())
        if a >= 255 {
            return String(format: "#%02X%02X%02X", r, g, b)
        }
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}
