import AppKit

/// Sleep/Restart/Shut Down for the Quick Launch menu's bottom section.
/// There's no first-class AppKit/IOKit call for these, so they go through
/// AppleScript's "System Events" — the same mechanism (and the same
/// underlying loginwindow machinery) the real Apple menu itself uses for
/// these exact commands.
public enum SystemPowerAction {
    case sleep, restart, shutDown

    private var appleScriptCommand: String {
        switch self {
        case .sleep: return "sleep"
        case .restart: return "restart"
        case .shutDown: return "shut down"
        }
    }

    public func perform() {
        guard let script = NSAppleScript(source: "tell application \"System Events\" to \(appleScriptCommand)") else { return }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
    }
}
