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

    public static let standard = TaskbarTheme(
        appearance: nil,
        taskbarBackground: nil,
        taskbarBorder: nil,
        buttonBackground: nil,
        buttonBorder: nil,
        buttonText: nil,
        buttonHighlight: .controlAccentColor
    )

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
            buttonHighlight: config.accentColor.flatMap(NSColor.init(hexString:)) ?? .controlAccentColor
        )
    }
}
