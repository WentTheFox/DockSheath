import AppKit

/// Diagnoses why DockSheath's screen-space reservation might not be working,
/// for display in a non-blocking warning to the user.
///
/// The primary signal is always the empirical bottom-inset measurement from
/// `DockGeometry` — it can't be stale. Dock preference reads (`autohide`,
/// `orientation`) are used only to word the diagnostic message, since
/// `cfprefsd` can lag behind very recent `defaults write` changes.
public enum DockHealthCheck {
    public enum Diagnosis: Equatable {
        case healthy
        case dockAutoHidden
        case dockNotAtBottom
        case unknownReservationMissing

        public var userFacingMessage: String {
            switch self {
            case .healthy:
                return "The Dock is reserving space correctly."
            case .dockAutoHidden:
                return "The Dock appears to be set to auto-hide. DockSheath needs the Dock visible " +
                    "(not auto-hidden) at the bottom of the screen to reserve space for the taskbar."
            case .dockNotAtBottom:
                return "The Dock appears to be positioned on the left or right instead of the bottom. " +
                    "DockSheath needs the Dock at the bottom of the screen."
            case .unknownReservationMissing:
                return "DockSheath can't detect any space reserved for the Dock at the bottom of the screen. " +
                    "Check Dock settings to make sure it's visible and positioned at the bottom."
            }
        }
    }

    public static func diagnose(screen: NSScreen) -> Diagnosis {
        guard !DockGeometry.isDockReservationHealthy(for: screen) else {
            return .healthy
        }

        if isDockAutoHidePreferenceEnabled() {
            return .dockAutoHidden
        }
        if let orientation = dockOrientationPreference(), orientation != "bottom" {
            return .dockNotAtBottom
        }
        return .unknownReservationMissing
    }

    private static func isDockAutoHidePreferenceEnabled() -> Bool {
        guard let value = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private static func dockOrientationPreference() -> String? {
        CFPreferencesCopyAppValue("orientation" as CFString, "com.apple.dock" as CFString) as? String
    }

    /// Resets Dock preferences to a state compatible with DockSheath's
    /// screen-reservation trick (visible, bottom-anchored) and restarts the
    /// Dock process to apply them. Callers MUST get explicit user confirmation
    /// before invoking this, since it changes system Dock preferences.
    public static func applyCompatibleDockSettings() {
        let defaultsPath = "/usr/bin/defaults"
        run(defaultsPath, ["write", "com.apple.dock", "autohide", "-bool", "false"])
        run(defaultsPath, ["write", "com.apple.dock", "orientation", "-string", "bottom"])
        run("/usr/bin/killall", ["Dock"])
    }

    private static func run(_ launchPath: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        try? process.run()
        process.waitUntilExit()
    }
}
