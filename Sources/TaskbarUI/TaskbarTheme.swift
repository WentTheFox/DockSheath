import AppKit
import JSON5Config

/// Resolved AppKit colors/appearance for the taskbar, derived from
/// `AppearanceConfig`. Any color left unset in config resolves to `nil`
/// here, which every consumer treats as "use the system-dynamic default" —
/// that's how the taskbar follows the system's light/dark appearance (and
/// accent color) unless the user overrides it.
public struct TaskbarTheme {
    public var appearance: NSAppearance?
    public var taskbarBackground: NSColor?
    public var taskbarBorder: NSColor?
    public var buttonBackground: NSColor?
    public var buttonBorder: NSColor?
    public var buttonText: NSColor?
    public var buttonHighlight: NSColor
    public var buttonFont: NSFont
    public var displayNumberFont: NSFont
    public var clockFont: NSFont

    public static let standard = TaskbarTheme(
        appearance: nil,
        taskbarBackground: nil,
        taskbarBorder: nil,
        buttonBackground: nil,
        buttonBorder: nil,
        buttonText: nil,
        buttonHighlight: .controlAccentColor,
        buttonFont: .systemFont(ofSize: 11),
        displayNumberFont: .boldSystemFont(ofSize: 10),
        clockFont: .systemFont(ofSize: 11, weight: .medium)
    )

    /// Resolves a user-typed font family name (e.g. "Avenir Next") to an
    /// `NSFont`, falling back to the system font (at `weight`) when `family`
    /// is nil, blank, or doesn't match an installed family.
    ///
    /// `NSFontManager.font(withFamily:...)` is used rather than
    /// `NSFont(name:size:)` because users type family names, not PostScript
    /// names (e.g. "AvenirNext-Regular") — `NSFont(name:)` only reliably
    /// matches the latter, so it would silently fail for most real-world
    /// input. `weight` only maps onto `.boldFontMask` here (`NSFontManager`'s
    /// trait mask has no clean equivalent for `.medium`), which only matters
    /// once a custom family is actually set — the no-override path always
    /// uses the exact `.standard` fallback fonts above.
    public static func resolvedFont(family: String?, size: Double, weight: NSFont.Weight = .regular) -> NSFont {
        let fallback = NSFont.systemFont(ofSize: CGFloat(size), weight: weight)
        guard let family, !family.trimmingCharacters(in: .whitespaces).isEmpty else { return fallback }
        let traits: NSFontTraitMask = weight == .bold ? .boldFontMask : []
        return NSFontManager.shared.font(withFamily: family, traits: traits, weight: 5, size: CGFloat(size)) ?? fallback
    }

    public static func resolve(_ config: AppearanceConfig) -> TaskbarTheme {
        let appearance: NSAppearance?
        switch config.theme {
        case "light":
            appearance = NSAppearance(named: .aqua)
        case "dark":
            appearance = NSAppearance(named: .darkAqua)
        default:
            appearance = nil
        }

        return TaskbarTheme(
            appearance: appearance,
            taskbarBackground: config.taskbarColors.background.flatMap(NSColor.init(hexString:)),
            taskbarBorder: config.taskbarColors.border.flatMap(NSColor.init(hexString:)),
            buttonBackground: config.buttonColors.background.flatMap(NSColor.init(hexString:)),
            buttonBorder: config.buttonColors.border.flatMap(NSColor.init(hexString:)),
            buttonText: config.buttonColors.text.flatMap(NSColor.init(hexString:)),
            buttonHighlight: config.accentColor.flatMap(NSColor.init(hexString:)) ?? .controlAccentColor,
            buttonFont: resolvedFont(family: config.buttonFont.family, size: config.buttonFont.size),
            displayNumberFont: resolvedFont(family: config.displayNumberFont.family, size: config.displayNumberFont.size, weight: .bold),
            clockFont: resolvedFont(family: config.clockFont.family, size: config.clockFont.size, weight: .medium)
        )
    }
}
