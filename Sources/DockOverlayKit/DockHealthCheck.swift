import AppKit

/// Diagnoses the state of DockSheath's screen-space reservation, for display
/// in a non-blocking status/warning to the user.
///
/// The primary signal is always the empirical inset measurement from
/// `DockGeometry` — it can't be stale. The `autohide` preference read is
/// used only to distinguish "Dock is auto-hidden, which is a supported mode"
/// from "something's actually wrong," since `cfprefsd` can lag behind very
/// recent `defaults write` changes.
public enum DockHealthCheck {
    public enum Diagnosis: Equatable {
        case healthy
        /// The Dock is set to auto-hide. This is a fully supported mode —
        /// DockSheath mirrors the real Dock's own show/hide-on-hover
        /// behavior rather than statically covering a reserved area, since
        /// an auto-hidden Dock doesn't reserve any space to cover.
        case healthyAutoHide
        case unknownReservationMissing

        public var userFacingMessage: String {
            switch self {
            case .healthy:
                return "The Dock is reserving space correctly."
            case .healthyAutoHide:
                return "The Dock is set to auto-hide. DockSheath mirrors it — hidden until you move " +
                    "the mouse to the screen edge, hidden again once you move away."
            case .unknownReservationMissing:
                return "DockSheath can't detect the Dock reserving space on any edge of the screen, " +
                    "even accounting for auto-hide. Check Dock settings to make sure it's enabled."
            }
        }
    }

    public static func diagnose(screen: NSScreen) -> Diagnosis {
        guard DockGeometry.currentReservation(for: screen) == nil else {
            return .healthy
        }

        if isAutoHideEnabled() {
            return .healthyAutoHide
        }
        return .unknownReservationMissing
    }

    public static func isAutoHideEnabled() -> Bool {
        guard let value = CFPreferencesCopyAppValue("autohide" as CFString, "com.apple.dock" as CFString) else {
            return false
        }
        return (value as? Bool) ?? false
    }

    /// Resets Dock preferences to a state compatible with DockSheath's
    /// static screen-reservation trick (visible, not auto-hidden) and
    /// restarts the Dock process to apply them. Only meaningful for
    /// `.unknownReservationMissing` — auto-hide itself is supported and
    /// doesn't need "fixing." Callers MUST get explicit user confirmation
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
