import AppKit
import ApplicationServices

/// Wraps the two OS permissions DockSheath needs: Accessibility (required,
/// for enumerating and controlling other apps' windows) and Screen Recording
/// (optional, only needed to read other apps' window titles).
public enum PermissionChecks {
    public static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user with the system Accessibility permission dialog if
    /// not already granted. Returns the trust state at call time (granting
    /// happens asynchronously in System Settings, so callers should re-check
    /// rather than assume this becomes true immediately).
    @discardableResult
    public static func requestAccessibilityAccess() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    public static var isScreenRecordingGranted: Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Prompts the user with the system Screen Recording permission dialog.
    /// Note: DockSheath may need to be relaunched after the user grants this
    /// for it to take effect — the grant isn't always recognized live.
    public static func requestScreenRecordingAccess() {
        CGRequestScreenCaptureAccess()
    }
}
