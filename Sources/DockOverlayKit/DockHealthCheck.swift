import AppKit

/// Diagnoses why DockSheath's screen-space reservation might not be working,
/// for display in a non-blocking warning to the user.
///
/// The primary signal is always the empirical inset measurement from
/// `DockGeometry` — it can't be stale. Dock preference reads (`autohide`)
/// are used only to word the diagnostic message, since `cfprefsd` can lag
/// behind very recent `defaults write` changes.
public enum DockHealthCheck {
    public enum Diagnosis: Equatable {
        case healthy
        case dockAutoHidden
        case unknownReservationMissing

        public var userFacingMessage: String {
            switch self {
            case .healthy:
                return "The Dock is reserving space correctly."
            case .dockAutoHidden:
                return "The Dock appears to be set to auto-hide. DockSheath needs the Dock visible " +
                    "(not auto-hidden) to reserve space for the taskbar."
            case .unknownReservationMissing:
                return "DockSheath can't detect any space reserved for the Dock on any edge of the screen. " +
                    "Check Dock settings to make sure it's visible."
            }
        }
    }

    /// Any edge — bottom, left, or right — is a valid, healthy Dock position;
    /// DockSheath follows whichever one the Dock is actually reserving.
    public static func diagnose(screen: NSScreen) -> Diagnosis {
        guard DockGeometry.currentReservation(for: screen) == nil else {
            return .healthy
        }

        if isDockAutoHidePreferenceEnabled() {
            return .dockAutoHidden
        }
        return .unknownReservationMissing
    }

    private static func isDockAutoHidePreferenceEnabled() -> Bool {
        guard let value = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) else {
            return false
        }
        return (value as? Bool) ?? false
    }

    /// Resets Dock preferences to a state compatible with DockSheath's
    /// screen-reservation trick (visible, not auto-hidden) and restarts the
    /// Dock process to apply them. Callers MUST get explicit user confirmation
    /// before invoking this, since it changes system Dock preferences.
    public static func applyCompatibleDockSettings() {
        run("/usr/bin/defaults", ["write", "com.apple.dock", "autohide", "-bool", "false"])
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
